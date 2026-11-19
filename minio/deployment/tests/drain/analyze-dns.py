import pathlib,json,re,collections,sys
r=pathlib.Path(sys.argv[1]) if len(sys.argv)==2 else pathlib.Path.cwd()
out={}
for arch in ('amd64','arm64'):
 e=r/'evidence'/arch/'evidence-dns'
 if not (e/'objects-final.sha256').exists(): continue
 def hashes(name): return dict(line.split()[::-1] for line in (e/name).read_text().splitlines())
 b,a=hashes('objects-before.sha256'),hashes('objects-final.sha256')
 assert len(b)==107 and len(a)==109 and all(a[k]==v for k,v in b.items())
 def pvc(name): return {i['metadata']['name']:(i['metadata']['uid'],i['spec']['volumeName']) for i in json.loads((e/name).read_text())['items']}
 assert len(pvc('pvc-before.json'))==3
 assert pvc('pvc-before.json')==pvc('pvc-after.json')==pvc('pvc-stopped.json')
 assert (e/'object-checks-final.txt').read_text().count(': OK')==109
 counts=(e/'storage-counts.txt').read_text().splitlines();assert len(counts)==3 and all(s.split()[1]=='109' for s in counts)
 raw=collections.Counter(l.split()[2] for l in (e/'guarded-raw.log').read_text().splitlines() if len(l.split())==3)
 s=(e/'guarded-adapter.log').read_text();adapter=collections.Counter(re.findall(r'exit=(\d+)',s))
 ts=[int(n) for n in re.findall(r'recovery_seconds=(\d+)',(e/'recovery-times.txt').read_text())];assert len(ts)==9
 for stage,want in [('offline',(2,1)),('final',(3,0))]:
  d=json.loads((e/f'admin-{stage}.json').read_text())['info']['backend'];assert (d['onlineDisks'],d['offlineDisks'])==want
 before=json.loads((e/'samepod-before.json').read_text());after=json.loads((e/'samepod-after.json').read_text());assert before['metadata']['uid']==after['metadata']['uid']
 bc={v['name']:v['restartCount'] for v in before['status']['containerStatuses']};ac={v['name']:v['restartCount'] for v in after['status']['containerStatuses']}
 assert bc['deployment-guard']==ac['deployment-guard'] and ac['minio']>bc['minio']
 spec=json.loads((e/'sts-dns.json').read_text())['spec']['template']['spec']
 server=next(c for c in spec['containers'] if c['name']=='minio')
 assert server['lifecycle']['preStop']['exec']['command']==['/bin/sh','-c','sleep 10']
 assert spec['terminationGracePeriodSeconds']==40
 assert next(v['value'] for v in server['env'] if v['name']=='MINIO_DNS_CACHE_TTL')=='1s'
 trace=[];p=r/f'dns-final-{arch}-trace.jsonl'
 if p.exists():
  trace=[d for l in p.read_text().splitlines() if (d:=json.loads(l)).get('api')=='s3.GetObject' and d.get('path','').removeprefix('/distributed/') in a]
 result={'raw':dict(raw),'adapter_exit':dict(adapter),'adapter_attempts':dict(collections.Counter(re.findall(r'http=(\d+)',s))),'trace_known_get':dict(collections.Counter(d.get('statusCode') for d in trace)),'unchanged_original_objects':107,'final_objects':109,'unchanged_pvcs':3,'metadata_each_drive':109,'pod_recreations':9,'recovery_seconds_min_max':[min(ts),max(ts)],'false_404_acceptance':raw.get('404',0)==0 and raw.get('CORRUPTION',0)==0}
 extra=e.parent/'evidence-dns-untraced'
 if (extra/'guarded-raw.log').exists():
  extra_raw=collections.Counter(l.split()[2] for l in (extra/'guarded-raw.log').read_text().splitlines())
  assert (extra/'checks.txt').read_text().count('109 objects verified')==3
  assert len((extra/'recovery-times.txt').read_text().splitlines())==3
  result['untraced_raw']=dict(extra_raw);result['untraced_recreations']=3
  result['false_404_acceptance']=result['false_404_acceptance'] and extra_raw.get('404',0)==0 and extra_raw.get('CORRUPTION',0)==0
 result['false_404_acceptance']=result['false_404_acceptance'] and not any(d.get('statusCode')==404 for d in trace)
 out[arch]=result
(r/'summary-dns.json').write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(out,indent=2))
