"""Check original upstream files byte-for-byte after vendoring/building."""
import hashlib,json,sys,tarfile
from pathlib import Path
out=Path(sys.argv[1]); result={}
for project in ('minio','mc'):
    count=0
    with tarfile.open(out/'upstream'/f'{project}.tar.gz') as archive:
        for item in archive:
            if not item.isfile(): continue
            relative=Path(*Path(item.name).parts[1:])
            original=archive.extractfile(item).read()
            actual=(out/'src'/project/relative).read_bytes()
            if hashlib.sha256(original).digest()!=hashlib.sha256(actual).digest():
                raise SystemExit(f'Changed upstream file: {project}/{relative}')
            count+=1
    result[project]={'original_files_checked':count,'changed_files':0}
print(json.dumps(result,indent=2))
