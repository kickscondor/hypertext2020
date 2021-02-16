require 'date'
require 'erb'
require 'yaml'

CONF = YAML.load_file(ARGV[0])

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

def esc(str)
  str.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
end

def link(href, text, domain)
  page = CONF['pages'][href]
  if page
    %{<a class="tc-tiddlylink" href="javascript:;" onclick="tw(this, '#{href.gsub(/\W+/, '-')}')">#{text}</a>}
  else
    if href !~ /\w+:\/\//
      if href =~ /^\//
        href = "https://#{domain}" + href
      else
        href = "https://#{domain}/#" + ERB::Util.url_encode(href)
      end
    end
    %{<a class="tc-tiddlylink-external" href="#{href}" target="_blank">#{text}</a>}
  end
end

def para(block, domain, level)
  if block.is_a? String
    block.gsub!(/^<<<$(.+?)^<<<(.+?)?$/m) { %{<blockquote>\n\n#$1\n\n#{$2 && %{\n\n<cite>#$2</cite>}}</blockquote>} }
    block.gsub!(/^"""$(.+?)^"""$/m) { $1.strip.split("\n").join("<br>") }
    block.gsub!(/(^\| .+?$.)+/m) { %{<pre><code>#{$&.gsub(/^\| /, '').gsub('`', '&#96;')}</code></pre>} }
    block.split("\n\n").map do |para|
      para = para.strip
      if para == "* * *"
        %{<hr>}
      else
        para = %{<p>\n#{para}\n</p>} if para[0] != "<"
        para = para.
          gsub(/^\^(\w+)\^\s*/) do |m|
            %{<span class="linkback-a" id="lbid-#$1"></span>}
          end.
          gsub(/<<footnotes?\s+"([^"]+)"\s+"(.+?)">>/m) do |m|
            %{<button class="tc-btn-invisible tc-slider" onmouseover="fn(this, 'show')"
              onmouseout="fn(this, 'show')" onclick="fn(this, 'clickshow')"><sup>#$1</sup>
              </button><span class="fn">#$2</span>}
          end.
          gsub(/\[\[\^(\w+)\^\]\]/m) do |m|
            %{<a class="linkback" href="javascript:;" onclick="linkback('#$1')">&lt;&lt; #{$1.capitalize}...</a>}
          end.
          gsub(/\[\[([^|]+?)\]\]/m) do |m|
            link($1, $1, domain)
          end.
          gsub(/\[\[(.+?)\|(.+?)\]\]/m) do |m|
            link($2, $1, domain)
          end.
          gsub(/(?<=^| )(\@\w+)/, %{<a href="javascript:tw('\\0')">\\0</a>}).
          gsub(/`(.+?)`/m) { %{<code>#{esc($1)}</code>} }.
          gsub(/~~(.+?)~~/m, %{<s>\\1</s>}).
          gsub(/\^\^(.+?)\^\^/m, %{<sup>\\1</sup>}).
          gsub(/''(.+?)''/m, %{<strong>\\1</strong>}).
          gsub(/(?<!:)\/\/(.+?)(?<!:)\/\//m, %{<em>\\1</em>}).
          gsub(/\-{2,3}/, '&mdash;').
          gsub(/\\(.)/, '\1')
      end
    end.join
  elsif block.is_a? Array
    %{<div class="convo">
      <a href="javascript:;" onclick="expand(this)" class="expand"></a>
      <div class="thread" style="z-index: #{level}">
        #{block.map { |b| div(b, level + 1) }.join}
      </div>
    </div>}
  end
end

def div(msg, level = 1)
  author = CONF['speakers'][msg[:author]]
  %{<div class="box box_purple_screen by-#{author['domain'].gsub(/\W+/, '-')}">
    <div class="box-shadow"><div></div></div>
    <div class="box-highlight"><div></div></div>
    <div class="box-fill"><div></div></div>
    <div class="box-content">
      <div class="title">
        <div class="title-shadow"><div></div></div>
        <div class="title-highlight"><div></div></div>
        <div class="title-fill"><div></div></div>
        <div class="title-content title-block">
					<h3 class="content">#{author['header']}</h1>
        </div>
      </div>
      <!-- The frame contents (text or comic log) -->
      <div class="box-block hypertext">
				#{msg[:blocks].map { |block| para(block, author['domain'], level) }.join}
      </div>
    </div>
  </div>}
end

txt = File.read(CONF['transcript'])
main = parse(txt).map do |msg|
  div(msg)
end.join
main += CONF['pages'].map do |name, content|
  %{<div id="twid-#{name.gsub(/\W+/, '-')}" class="wikipage">
    <a class="close" href="javascript:;" onclick="twc(this)">x</a>
    <div class="hypertext">
      #{para(content, 'philosopher.life', 0)}
    </div>
  </div>}
end.join

html = File.read(CONF['template']).
  gsub("%MAIN%", main)
File.write(CONF['output'], html)
