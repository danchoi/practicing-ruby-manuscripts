require 'yaml'
require 'pathname'
require 'nokogiri'
require 'github/markdown' # gem install github-markdown
require 'fileutils'

if `which kindlerb` == ''
  abort "Please run `gem install kindlerb`"
end

# Run this from the kindle/ subdirectory

def add_head_section(doc, title)
  head = Nokogiri::XML::Node.new "head", doc
  title_node = Nokogiri::XML::Node.new "title", doc
  title_node.content = title
  title_node.parent = head
  css = Nokogiri::XML::Node.new "link", doc
  css['rel'] = 'stylesheet'
  css['type'] = 'text/css'
  css['href'] = "#{Dir.pwd}/kindle.css"
  css.parent = head
  doc.at("body").before head
end


def wrap_html(title, body)
  doc = Nokogiri::HTML(body)
  add_head_section doc, title
  # fix lists
  doc.xpath("//li/p").each {|p| p.swap p.children}
  download_images! doc
  doc.serialize
end

def run_shell_command cmd
  puts "  #{cmd}"
  `#{cmd}`
end

def download_images! doc
  doc.search('img').each {|img|
    src = img[:src] 
    /(?<img_file>[^\/]+)$/ =~ src

    FileUtils::mkdir_p 'images'
    FileUtils::mkdir_p 'processed_images'
    unless File.size?("images/#{img_file}")
      run_shell_command "curl -Ls '#{src}' > images/#{img_file}"
      if img_file !~ /(png|jpeg|jpg|gif)$/i
        filetype = `identify images/#{img_file} | awk '{print $2}'`.chomp.downcase
        run_shell_command "cp images/#{img_file} images/#{img_file}.#{filetype}"
        img_file = "#{img_file}.#{filetype}"
      end
    end
    processed_image_path = "processed_images/#{img_file.gsub('%20', '_').sub(/(\.\w+)$/, "-grayscale.gif")}"
    sleep 0.1
    unless File.size?(processed_image_path)
      run_shell_command "convert images/#{img_file} -compose over -background white -flatten -resize '300x200>' -alpha off #{processed_image_path}"
    end
    img['src'] = [Dir.pwd, processed_image_path].join("/")
  }
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
    File.write(apath, html)
  }
}

exec "kindlerb"
