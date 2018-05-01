# Usage:
# ./stream-wistia-video <hashed_id>

require 'net/http'
require 'json'
require 'pp'
HASHED_ID = ARGV[0]

def ensure_local_file(hashed_id)
  Dir.mkdir('cache') if !File.exists?('cache')
  if !File.exists?("cache/#{hashed_id}.bin")
    puts 'Video not found locally. Checking Wistia.'
    uri = URI("https://fast.wistia.com/embed/medias/#{HASHED_ID}.json")
    response = Net::HTTP.get(uri)
    media_info = JSON.parse(response)
    puts 'Video found on Wistia.'
    valid_assets = media_info['media']['assets'].select{|a| a['type'].include?('mp4')}
    smallest_asset = valid_assets.sort{|a,b| a['size'] <=> b['size']}.first
    puts 'Downloading.'
    `curl #{smallest_asset['url']} --output cache/#{hashed_id}.bin`
    puts 'Download complete.'
  else
    puts 'Video found locally.'
  end
end

def get_serial_port
  puts 'Locating serial port.'
  if `uname -a`.include?('raspberrypi')
    `ls /dev/ttyACM*`.split("\n").first
  else
    `ls /dev/tty.usbmodem*`.split("\n").first
  end
end

ensure_local_file HASHED_ID
serial_port = get_serial_port
sketchbook_directory = `echo $(cd "$(dirname "streamer/streamer.pde")" && pwd)`.chomp
media_file = "#{`pwd`.chomp}/cache/#{HASHED_ID}.bin"

# Time to shell!
cmd = %Q{processing-java --sketch=#{sketchbook_directory}  --run #{serial_port} "#{media_file}"}
puts "Executing: #{cmd}"
exec(cmd)
