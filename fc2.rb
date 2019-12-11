require 'open3'

MODEL_MACHINE = 'ubuntu@172.31.7.60'

LOG_FILE = File.open(File.join(__dir__, "out.log"), "a")


def list_files
  cmd = "ssh #{MODEL_MACHINE} 'ls -tr1'"
  LOG_FILE << stdout
  LOF_FILE << "\n------------------------------------\n"
end

list_files
list_files

