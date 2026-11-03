import Base
import ./examples/Parallel.bend as ParallelExample

# Native dispatch may use CPU fallback; this example never claims GPU attestation.
def main() -> IO(Unit):
  ParallelExample.main()
