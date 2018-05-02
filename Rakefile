require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rdoc/task"

RSpec::Core::RakeTask.new(:spec)

task default: :spec

RDoc::Task.new do |t|
  t.rdoc_dir = "www/build/rdoc"
  t.options += [
    "--line-numbers",
    "--title", "Fend: Small and extensible data validation toolkit",
    "--markup", "markdown",
    "--format", "hanna", # requires the hanna-nouveau gem
    "--main", "README.md",
    "--visibility", "public"
  ]
  t.rdoc_files.add Dir[
    "README.md",
    "lib/**/*.rb",
    "doc/*.md",
    "doc/release_notes/*.md"
  ]
end

task rdoc: "website:rdoc_github_links"
task rdoc: "website:toc_links_fix"

namespace :website do
  task :build do
    sh "cd www; bundle exec jekyll build; cd .."
    sh "rake rdoc"
  end

  task :rdoc_github_links do
    begin
      require "oga"

      revision = `git rev-parse HEAD`.chomp
      github_icon = '<img src="/images/gh.png" width=13 height=13 style="position:absolute; margin-left:5px;">'

      Dir["www/build/rdoc/classes/**/*.html"].each do |class_file|
        html = File.read(class_file)
        document = Oga.parse_html(html)

        file_link = document.css(".header .paths li a").first
        file_link_html = file_link.to_xml

        file_link["href"] = "https://github.com/aradunovic/fend/blob/#{revision}/#{file_link.text}"

        new_html = html.sub(file_link_html, "#{file_link.to_xml} #{github_icon}")

        File.write(class_file, new_html)
      end
    rescue LoadError
    end
  end

  task :toc_links_fix do
    begin
      require "cgi"
      require "oga"

      readme_html = File.read("www/build/rdoc/files/README_md.html")
      document = Oga.parse_html(readme_html)

      # https://github.com/ruby/rdoc/blob/master/lib/rdoc/markup/to_label.rb#L35
      to_label = ->(text) { "#label-#{CGI.escape(text).gsub('%', '-').sub(/^-/, '')}" }

      links = document.css("ul li p a").each_with_object([]) do |link, result|
        link_html = link.to_xml

        link["href"] = to_label.call(link.text)

        result << { old: link_html, new: link.to_xml }
      end

      new_html = readme_html

      links.each do |link|
        new_html = new_html.sub(link[:old], link[:new])
      end

      File.write("www/build/rdoc/files/README_md.html", new_html)
    rescue LoadError
    end
  end
end
