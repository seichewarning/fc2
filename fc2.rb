require 'open3'
require 'aws-sdk-s3'
require 'time'

# these constants need to be configured
MODEL_MACHINE = 'ubuntu@172.31.7.60'
BASE_FORECAST_OUTPUT_DIR = '/home/ubuntu/Build_WRF/WRF-4.1.2/test/em_real/'
S3_BUCKET_NAME = 'mcm-modeltest'
DOMAINS = ['d01', 'd02']

# ASSUMPTIONS:
#   There are 4 model runs per day.
#   The model run files will be outputed to their run folder.  For example the 6Z
#   run would be in the model machine output folder....
#   '/home/ubuntu/Build_WRF/WRF-4.1.2/test/em_real/0600/'
#


# helper constants, don't touch
LOG_FILE = File.open(File.join(__dir__, "out.log"), "a")
S3 = Aws::S3::Resource.new
BUCKET = S3.bucket(S3_BUCKET_NAME)


# main loop
def main_run
  if (!is_good_time_to_run?)
    return
  end

  sync_files = get_filesname_to_sync_per_domain

  sync_files.each do |sync_file|
    already_exists = does_s3_object_exist?(sync_file[:object_name])
    if (already_exists)
      next
    end

    copy_file_to_s3(sync_file)
  end
end












# will return one of [0, 6, 12, 18]
def get_current_run_time
  return ((Time.now.utc.hour / 6) * 6)
end


# will return something like '2019-12-05'
def get_date_string
  return Time.now.utc.strftime("%Y-%m-%d")
end


# will return one of ['0000', ... '1800']
def get_current_run_time_string
  zhour = get_current_run_time
  s = "#{zhour}00"
  if (zhour < 10)
    s = "0" + s
  end
  return s
end


# takes "wrfout_d01_2019-12-14_22:00:00" and returns
# integer time_t of the date time part
def get_time_t_of_filename(filename)
  datetime = filename.split("_")[2] + " " + filename.split("_")[3]
  return Time.parse(datetime).to_i
end


def is_good_time_to_run?
  cur_hour = Time.now.utc.hour
  ltext = "Checking if good time to run with current UTC hour of #{cur_hour}..."
  if ((cur_hour % 6) != 0)
    ltext += "Yes"
    log(ltext)
    return true
  else
    ltext += "No"
    log(ltext)
    return false
  end
end

# will return array like:
#["wrfout_d01_2019-12-14_22:00:00", "wrfout_d01_2019-12-14_23:00:00", "wrfout_d01_2019-12-15_00:00:00", "wrfout_d01_2019-12-15_01:00:00", "wrfout_d02_2019-12-14_23:00:00", "wrfout_d02_2019-12-15_00:00:00"]
def get_list_of_filenames
  cmd = "ssh #{MODEL_MACHINE} 'ls -tr1 #{BASE_FORECAST_OUTPUT_DIR}#{get_current_run_time_string}'"
  cmd = "ls -tr1 #{BASE_FORECAST_OUTPUT_DIR}#{get_current_run_time_string}"
  files = run_cmd(cmd)
  return files.split
end


# this sorts the file names on the model machine by domain and in order of
# decreasing date, return a 2-d array like:
# [["wrfout_d01_2019-12-15_01:00:00", "wrfout_d01_2019-12-15_00:00:00", "wrfout_d01_2019-12-14_23:00:00", "wrfout_d01_2019-12-14_22:00:00"], ["wrfout_d02_2019-12-15_00:00:00", "wrfout_d02_2019-12-14_23:00:00"]]
def get_sorted_filenames_by_domain
  domains = []

  filenames = get_list_of_filenames
  DOMAINS.each_with_index do |domain, index|
    domains[index] = []
    filenames.each do |filename|
      if (filename.include?(domain))
        domains[index].push(filename)
      end
    end
  end

  domains.each do |domain|
    domain.sort! do |a, b|
      time_a = get_time_t_of_filename(a)
      time_b = get_time_t_of_filename(b)
      time_b <=> time_a
    end
  end
  return domains
end

# given domain and file name create uri similar to
# s3://mcm-modeltest/2019-12-05/0600/d01/wrfout_d01_2019-12-14_23:00:00
def get_s3_bucket_uri(domain_name, filename)
  s = "s3://#{S3_BUCKET_NAME}/"
  s += "#{get_s3_bucket_name(domain_name, filename)}"
end


# given domain and filename return something similar to:
#   2019-12-05/0600/d01/wrfout_d01_2019-12-14_23:00:00
def get_s3_bucket_name(domain_name, filename)
  s = "#{get_date_string}/"
  s += "#{get_current_run_time_string}/"
  s += "#{domain_name}/"
  s += "#{filename}"
  return s
end


# this returns an array or mapped files that might possibly need
# to be copied.  It will be used to create the aws cli commands
# after a check has been done to make sure the destination 
# file doesn't already exist.  Sample output..
# [
#   {
#     :local_origin=>"/home/ubuntu/Build_WRF/WRF-4.1.2/test/em_real/1800/wrfout_d01_2019-12-15_00:00:00",
#     :object_name=>"2019-12-14/1800/d01/wrfout_d01_2019-12-15_00:00:00",
#     :dest_uri=>"s3://mcm-modeltest/2019-12-14/1800/d01/wrfout_d01_2019-12-15_00:00:00"
#   },
#   {
#     :local_origin=>"/home/ubuntu/Build_WRF/WRF-4.1.2/test/em_real/1800/wrfout_d02_2019-12-14_23:00:00",
#     :object_name=>"2019-12-14/1800/d02/wrfout_d02_2019-12-14_23:00:00",
#     :dest_uri=>"s3://mcm-modeltest/2019-12-14/1800/d02/wrfout_d02_2019-12-14_23:00:00"
#   }
# ]
def get_filesname_to_sync_per_domain
  files_to_sync = []
  sorted_filenames = get_sorted_filenames_by_domain

  sorted_filenames.each_with_index do |filenames, index|
    if (filenames.length <= 1)
      next
    end
    domain_name = DOMAINS[index]
    filename = filenames[1]
    local_origin = "#{BASE_FORECAST_OUTPUT_DIR}#{get_current_run_time_string}/#{filename}"
    object_name = get_s3_bucket_name(domain_name, filename)
    dest_uri = get_s3_bucket_uri(domain_name, filename)
    files_to_sync.push({local_origin: local_origin, object_name: object_name, dest_uri: dest_uri})
  end
  return files_to_sync
end


def does_s3_object_exist?(object_name)
  sltext = "Checking to see if object #{object_name} exists in bucket #{S3_BUCKET_NAME} ..."
  does_exist = BUCKET.object(object_name).exists?
  sltext += (does_exist) ? "Yes\n" : "No\n"
  log(sltext)
  return does_exist
end


def copy_file_to_s3(sync_file)
  cmd = "aws s3 cp #{sync_file[:local_origin]} #{sync_file[:dest_uri]}"
  run_cmd(cmd)
end


# this runs the given command on the model machine through ssh
# and logs it.
def run_cmd(cmd)
  cmd = "ssh #{MODEL_MACHINE} '#{cmd}'"
  log_text  = "Running command:\n\n#{cmd}\n\n"
  stdout, stderr, status = Open3.capture3(cmd)
  stdout.gsub!(/\r\n?/, "\n");
  log_text += "stdout:\n #{stdout.to_s}\n"
  log(log_text)
  return stdout
end

#logging helper and formatter with date time
def log(in_text)
  LOG_FILE << "\n#{Time.now.utc} -- #{in_text}\n"
  LOG_FILE.flush
end

main_run
