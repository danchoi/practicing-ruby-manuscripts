require 'yaml'
require 'pathname'
require 'nokogiri'
require 'github/markdown' # gem install github-markdown
if `which kindlerb` == ''
  abort "Please run `gem install kindlerb`"
end

# Run this from the kindle/ subdirectory


def wrap_html(title, body)
  "<html><head><title>#{title}</title></head><body>#{body}</body></html>"
end


cover_path = nil
date = Time.now.strftime('%F')
document = {
  'doc_uuid' => "Practicing-Ruby-#{date}",
  'title' => "Practicing Ruby",
  'author' => "Gregory Brown",
  'publisher' => "Gregory Brown",
  'subject' => "Ruby Programming",
  'date' => date,
  'masthead' => nil,
  'cover' => cover_path,
  'mobi_outfile' => "practicing-ruby-#{date}.mobi"
}

puts document.inspect
File.write("_document.yml", document.to_yaml)

# loop over the volumes and turn them into sections

path  = Pathname.new("../articles")
sections = path.children

`mkdir -p sections`
sections.each_with_index {|vol, i|
  puts "Processing #{vol.to_s}"

  vol_toc = File.readlines(vol + "README.md").select{|line| line =~ /Issue/}.reduce({}) {|memo,x|
    key = x[/Issue \d+\.([^:]+)/,1].gsub('.', '')
    title = x[/: ([^\]]+)/, 1]
    memo[key] = title
    memo
  }

  puts vol_toc 

  spath = "sections/%.3d" % i
  `mkdir -p #{spath}`

  # save section title in file
  stitle = "Volume #{i + 1}"
  File.write(spath + '/_section.txt', stitle)

  # process each article
  vol.children.delete_if {|x| x.to_s =~ /README/}.each_with_index {|article, j| 
    puts article.to_s
    apath = "sections/%.3d/%.3d.html" % [i, j]
    md_content = File.read article    
    # this is a hack because some of the text includes a string like 'Issue #21' where #21 
    # would otherwise be incorrectly turned into a h1 header by Markdown.
    md_content.gsub!(/^#[^# ]/, '&nbsp;\&')

    html_content = GitHub::Markdown.render(md_content)
    title_key = article.to_s[/\/(\d{3}\w?)/, 1].sub(/0+/, '') # strip leading 0s
    title = vol_toc[title_key]
    raise "No title found for #{title_key}" unless title
    puts title
    html = wrap_html(title, "<h1>#{title}</h1>" + html_content)

    # fix lists
    d = Nokogiri::HTML(html)
    d.xpath("//li/p").each {|p| p.swap p.children}
    File.write(apath, d.serialize)
  }
}

exec "kindlerb"
