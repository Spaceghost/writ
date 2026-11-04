import Base
import ../../../Backplane.bend as Backplane
import ../../../lib/Sha256.bend as Sha256

# Compatibility entry points for the rclone contribution. The shared pure Bend
# implementation is also used to identify native filesystem seal manifests.
def digest_hex(body: String) -> Maybe<&2, Backplane.ArtifactId>:
  Sha256.digest_hex(body)

def artifact_hex(artifact: Backplane.ArtifactId) -> String:
  Sha256.artifact_hex(artifact)
