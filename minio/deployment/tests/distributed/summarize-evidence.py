import json, pathlib, collections, re, sys
root=pathlib.Path(sys.argv[1]) if len(sys.argv) == 2 else pathlib.Path.cwd()
out={}
for arch in ('amd64','arm64'):
 e=root/'evidence'/arch/'evidence'
 result={}
 for phase in ('baseline','guarded'):
  raw=collections.Counter(line.split()[2] for line in (e/(phase+'-raw.log')).read_text().splitlines() if len(line.split())==3)
  adapter=(e/(phase+'-adapter.log')).read_text()
  result[phase]={'raw_http':dict(raw),'adapter_exit':dict(collections.Counter(re.findall(r'exit=(\d+)',adapter))), 'adapter_http_attempts':dict(collections.Counter(re.findall(r'http=(\d+)',adapter)))}
  assert 'CORRUPTION' not in raw
 def pvcs(name):
  return {i['metadata']['name']:(i['metadata']['uid'],i['spec']['volumeName']) for i in json.loads((e/name).read_text())['items']}
 assert pvcs('pvc-before.json')==pvcs('pvc-stopped.json')==pvcs('pvc-after.json')
 result['same_original_pvcs']=len(pvcs('pvc-before.json'))
 def hashes(name):
  return dict(line.split()[::-1] for line in (e/name).read_text().splitlines())
 before=hashes('objects-before.sha256'); after=hashes('objects-final.sha256')
 assert len(before)==103 and len(after)==105
 assert all(after[k]==v for k,v in before.items())
 result['unchanged_original_objects']=len(before);result['final_objects']=len(after)
 for stage,want in [('offline',(2,1)),('final',(3,0))]:
  b=json.loads((e/('admin-'+stage+'.json')).read_text())['info']['backend']
  assert (b['onlineDisks'],b['offlineDisks'])==want
  result[stage+'_disks']=[b['onlineDisks'],b['offlineDisks']]
 assert (e/'object-checks-final.txt').read_text().count(': OK')==105
 counts=(e/'storage-counts.txt').read_text().splitlines()
 assert len(counts)==3 and all(line.split()[1]=='105' for line in counts)
 result['metadata_entries_each_drive']=105
 times=[int(n) for n in re.findall(r'recovery_seconds=(\d+)',(e/'recovery-times.txt').read_text())]
 assert len(times)==9
 result['pod_recreations']=len(times);result['recovery_seconds_min_max']=[min(times),max(times)]
 result['checks']=(e/'checks.txt').read_text().splitlines()
 out[arch]=result
(root/'summary.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps(out,indent=2))
