require 'rubygems'
require 'bundler/setup'

require 'dotenv'
require 'wistia'

Dotenv.load
Wistia.password = ENV['WISTIA_API_PASSWORD']
# Usage:
# ./stream-wistia-video <hashed_id>

HASHED_ID = ARGV[0]

def ensure_local_file(hashed_id)
  Dir.mkdir('cache') if !File.exists?('cache')
  if !File.exists?("cache/#{hashed_id}.bin")
    puts 'Video not found locally.'
    media = Wistia::Media.find(HASHED_ID)
    puts 'Video found on Wistia.'
    media_asset = media.assets.select{|i| i.type == 'OriginalFile'}.first
    puts 'Downloading.'
    `curl #{media_asset.url} --output cache/#{hashed_id}.bin`
    puts 'Download complete.'
  else
    puts 'Video found locally.'
  end
end

def get_serial_port
  puts 'Locating serial port.'
  `ls /dev/tty.usbmodem*`.split("\n").first
end

ensure_local_file HASHED_ID
serial_port = get_serial_port
sketchbook_directory = `echo $(cd "$(dirname "streamer/streamer.pde")" && pwd)`.chomp
media_file = "#{`pwd`.chomp}/cache/#{HASHED_ID}.bin"

# Time to shell!
cmd = %Q{processing-java --sketch=#{sketchbook_directory}  --run #{serial_port} "#{media_file}"}
puts "Executing: #{cmd}"
exec(cmd)
