# SYNTHETIC fixtures for SupervisorProvisionTests: the RFC 8032 section 7.1
# TEST 1 and TEST 2 secret keys are published, so these signatures
# authenticate nobody. Prints name, byte length and hex for each fixture.
import struct
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
t1=Ed25519PrivateKey.from_private_bytes(bytes.fromhex("9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60"))
t2=Ed25519PrivateKey.from_private_bytes(bytes.fromhex("4ccd089b28ff96da9db6c346ec114e0f5b8a319f35aba624da8cf6ed4fb8a6fb"))
ctx=b"WRIT-LINUXSUP1-RECORD"
rest=[1,2,3,2,1,101,2,102,
 5,1,101,5,2,102,6,1,103,9,1,104,7,2,105,5,
 4,1,10,4,5,1,11,4,7,2,20,8,6,2,20,9,6,
 2,1,3128432319,2399260650,1094795486,1571693091,2953011619,2518121116,3021012833,4060091821,
 2,3820012610,2566659092,2600203464,2574235940,665731556,1687917388,2761267483,2018687061]
def b(ws): return b"".join(struct.pack("<I",w) for w in ws)
body=b([4,2]+rest)
out={}
out["canary_hex"]=body.hex()
out["canary_signed_hex"]=(body+t1.sign(ctx+body)).hex()
out["canary_other_key_hex"]=(body+t2.sign(ctx+body)).hex()
out["canary_no_context_hex"]=(body+t1.sign(body)).hex()
v3=b([3]+rest); out["canary_v3_signed_hex"]=(v3+t1.sign(ctx+v3)).hex()
st=b([4,1]+rest); out["canary_stale_signed_hex"]=(st+t1.sign(ctx+st)).hex()
for k,v in out.items(): print(k,len(v)//2,v)
