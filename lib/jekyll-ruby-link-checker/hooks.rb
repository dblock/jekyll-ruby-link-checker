# frozen_string_literal: true

# Low priority, so links are collected after other plugins have changed the content.
Jekyll::Hooks.register :site, :pre_render, priority: :low do |site|
  Jekyll::RubyLinkChecker::Checker.start(site)
end

Jekyll::Hooks.register %i[pages documents], :post_render, priority: :low do |page|
  Jekyll::RubyLinkChecker::Checker.current&.collect(page)
end

Jekyll::Hooks.register :site, :post_write, priority: :low do |_site|
  Jekyll::RubyLinkChecker::Checker.finish
end
