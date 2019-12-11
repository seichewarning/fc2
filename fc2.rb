require 'open3'

MODEL_MACHINE = 'ubuntu@172.31.7.60'

LOG_FILE = File.open(File.join(__dir__, "out.log"), "a")


def list_files
  cmd = "ssh #{MODEL_MACHINE} 'ls -tr1'"
  LOG_FILE << "Running command...\n\t#{cmd}\n"
  stdout, stderr, status = Open3.capture3(cmd)
  LOG_FILE << "Time now = #{Time.now.utc}"
  LOG_FILE << "STDOUT\n"
  LOG_FILE << stdout
  LOG_FILE << "\n--------------------------------------------\n"
  LOG_FILE << "STDERR\n"
  LOG_FILE << stdout
  LOG_FILE << "\n--------------------------------------------\n"
  LOG_FILE << "STDOUT\n"
  LOG_FILE << stdout
  LOG_FILE << "\n--------------------------------------------\n"
  LOG_FILE << "Time now = #{Time.now.utc}"
end

list_files
list_files

