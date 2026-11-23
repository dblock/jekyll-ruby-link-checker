# frozen_string_literal: true

# Builds a small Jekyll site in a temporary directory with the plugin's hooks.
module SiteHelper
  def with_env(env)
    previous = env.keys.to_h { |key| [key, ENV.fetch(key, nil)] }
    env.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  def write_files(source, files)
    files.each do |path, content|
      file = File.join(source, path)
      FileUtils.mkdir_p(File.dirname(file))
      File.write(file, content)
    end
  end

  def page(body, front_matter = {})
    "#{front_matter.merge('layout' => nil).to_yaml}---\n#{body}\n"
  end

  def build_site(dir, files, link_checker: {}, env: { 'LINK_CHECKER' => '1' }, config: {})
    write_files(File.join(dir, 'source'), files)
    site = Jekyll::Site.new(site_config(dir, link_checker, config))
    unset = %w[LINK_CHECKER LINK_CHECKER_CACHE LINK_CHECKER_REPORT LINK_CHECKER_FAIL LINK_CHECKER_CHANGED_FILES
               LINK_CHECKER_BASELINE LINK_CHECKER_DEAD_LINKS]
            .to_h { |name| [name, nil] }
    with_env(unset.merge(env)) { site.process }
    site
  end

  def site_config(dir, link_checker, config)
    Jekyll.configuration(
      {
        'source' => File.join(dir, 'source'),
        'destination' => File.join(dir, '_site'),
        'url' => 'https://www.example.com',
        'quiet' => true,
        'link_checker' => link_checker
      }.merge(config)
    )
  end

  def stub_url(url, code)
    Typhoeus.stub(url).and_return(Typhoeus::Response.new(code: code, body: ''))
  end
end
