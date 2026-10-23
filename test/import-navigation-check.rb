require "json"
results = []
Theme.transaction do
  %w[before after].each do |version|
    theme = RemoteTheme.import_theme_from_directory("/tmp/vcai-#{version}")
    theme.update_setting(:vcai_navigation_enabled, true)
    theme.update_javascript_cache!
    js = theme.javascript_cache.content
    included = js.include?("api-initializers/vcai-conversation-navigation") && js.include?("components/vcai-conversation-navigation")
    raise "Unexpected navigation inclusion: #{version}" unless included == (version == "after")
    %i[common_theme desktop_theme mobile_theme].each { |target| Stylesheet::Manager.new(theme_id: theme.id).stylesheet_details(target) }
    errors = theme.theme_fields.where.not(error: [nil, ""]).pluck(:name, :error)
    raise errors.inspect if errors.any?
    results << {version: version, navigation_modules_included: included, compile_errors: errors}
  end
  raise ActiveRecord::Rollback
end
puts "NAV_REPAIR=" + JSON.generate(results)
