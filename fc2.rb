require 'open3'

MODEL_MACHINE = 'ubuntu@172.31.7.60'
BASE_FORECAST_OUTPUT_DIR = 'Build_WRF/WRF-4.1.2/test/em_real/'

LOG_FILE = File.open(File.join(__dir__, "out.log"), "a")


def list_files
  cmd = "ssh #{MODEL_MACHINE} 'ls -tr1'"
  run_cmd(cmd)
end

def run_cmd(cmd)
  log_text "Running command:\n\t\t#{cmd}\n"
  stdout, stderr, status = Open3.capture3(cmd)
  log_text "STDOUT:\n#{stdout}\nSTDERR:\n#{stderr}\nSTATUS:\n#{status}\n"
  log(log_text)
end

def log(in_text)
  LOG_FILE << "\n#{Time.now.utc}   --------------------------\n#{in_text}\n"
end

list_files




