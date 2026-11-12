import Base
import ../../contrib/rclone/bend/Wire.bend as W

# Public sample bytes, written only when the owner invokes the app's sample
# action against a configured destination. These are real files and transfers,
# not synthetic authority records or a substitute for an authenticated issuer.
def manifest() -> String:
  "Examples/project-notes.txt\t1\t" ++ W.hex_ascii("Writ project notes\n\nThis public sample has a private managed-transfer restriction.\nTry copying it to a public-only destination: Writ must refuse before upload.\nCopy it to approved private storage, then inspect the retained original source.\nEdit this file in your normal editor to create another version.\n") ++ "\n" ++
  "Examples/readme.txt\t0\t" ++ W.hex_ascii("Welcome to Writ Drive\n\nThis sample is public and can be copied to any enabled destination.\nThe Files view lists metadata without downloading payloads.\nOpen a file to keep it in your working folder; save normally to sync edits.\nHistory restores old bytes while retaining the current restrictions.\nActivity reports actual decisions and verified storage confirmations.\n") ++ "\n"
