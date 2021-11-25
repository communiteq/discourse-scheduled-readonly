# frozen_string_literal: true

# name: discourse-scheduled-readonly
# about: schedule readonly moments during the weekend and holidays
# version: 1.0
# authors: richard@discoursehosting.com
# url: https://github.com/communiteq/discourse-scheduled-readonly

enabled_site_setting :scheduled_readonly_enabled

PLUGIN_NAME ||= "discourse_scheduled_readonly".freeze

after_initialize do
  require File.expand_path('../jobs/scheduled/scheduled_readonly.rb', __FILE__)
end
