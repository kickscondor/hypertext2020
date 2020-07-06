require 'date'

def parse(str, author = nil)
  str.split(/^\-{3}$/).map do |msg|
    msg = msg.strip
    if msg =~ /\A@/
      byline, content = msg.split("\n\n", 2)
    else
      byline = author
      content = msg
    end

    author, time, permalink = byline.split(" / ")
    time = DateTime.parse(time) rescue nil
    blocks = []
    while content
      start, mid = content.split("\n  ", 2)
      blocks.push(start.strip) if start
      break unless mid

      start, content = mid.split(/^\n(?=\S)/, 2)
      blocks.push(parse(start.gsub(/^  /, ''), byline)) if start
    end
    {author: author, time: time, permalink: permalink, blocks: blocks}
  end
end

txt = File.read(ARGV[0])
main = parse(txt).map do |msg|
  p msg
end.join

html = File.read(ARGV[1]).
  gsub("<main></main>", "<main>#{main}</main>")
File.write('index.html', html)
