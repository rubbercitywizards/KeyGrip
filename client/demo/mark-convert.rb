require 'nokogiri'

html = nil
IO.popen("markdown \"#{ARGV[0]}\"") do |f|
  html = f.read
end

doc = Nokogiri::HTML(html)

puts "--- script\n"
doc.css('body').children.each do |node|
  if node.name == 'pre'
    puts "--- clip"
    puts node.content
    puts "--- script\n"
  else
    if node.name == 'h1' or node.name == 'h2'
      puts "--- script\n"
    end
    puts node
  end
end
