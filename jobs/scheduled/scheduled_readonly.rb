# frozen_string_literal: true

module Jobs
  class ScheduledReadonly < Jobs::Scheduled
    every 5.minutes
  
    def execute(_args)
      return unless SiteSetting.scheduled_readonly_enabled

      tz = Time.zone

      begin
        Time.zone = SiteSetting.scheduled_readonly_timezone
        now = Time.zone.at(Time.now)

        must_ro_w = false
        must_ro_e = false
        err = false
        ro_message = ''

        if SiteSetting.scheduled_readonly_weekend_enabled
          start_day = SiteSetting.scheduled_readonly_weekend_start_weekday.to_i
          start_hour = SiteSetting.scheduled_readonly_weekend_start_time
          end_day = SiteSetting.scheduled_readonly_weekend_end_weekday.to_i
          end_hour = SiteSetting.scheduled_readonly_weekend_end_time
  
          if start_day <= end_day 
            Rails.logger.error("Weekend ends before it starts")
            err = true
          end
  
          # take advantage of the fact that Sunday is weekday 0
          must_ro_w = true if ((now.wday == start_day) && (now.strftime('%H:%M') >= start_hour))
          must_ro_w = true if ((now.wday == end_day) && (now.strftime('%H:%M') < end_hour))
          must_ro_w = true if (now.wday > start_day)
          must_ro_w = true if (now.wday < end_day)
  
          ro_message = SiteSetting.scheduled_readonly_weekend_banner_text if must_ro_w
        end

        if SiteSetting.scheduled_readonly_event_enabled
          start_moment = "#{SiteSetting.scheduled_readonly_event_start_date} #{SiteSetting.scheduled_readonly_event_start_time}"
          end_moment = "#{SiteSetting.scheduled_readonly_event_end_date} #{SiteSetting.scheduled_readonly_event_end_time}"
          current_moment = now.strftime('%Y-%m-%d %H:%M')
          must_ro_e = true if current_moment >= start_moment
          must_ro_e = false if current_moment >= end_moment

          ro_message = SiteSetting.scheduled_readonly_event_banner_text if must_ro_e
        end

      rescue => e
        Rails.logger.error("Exception in scheduled_readonly #{e.message}")
        err = true
      end

      Time.zone = tz

      if err
        Rails.logger.error("Error, so disable readonly mode")
        SiteSetting.scheduled_readonly_notice = ''
        if SiteSetting.scheduled_readonly_prevent_posting
          SiteSetting.prevent_posting_enabled = false if SiteSetting.respond_to?(:prevent_posting_enabled)
        else
          Discourse.disable_readonly_mode if (Discourse.readonly_mode?)
          MessageBus.publish('/refresh_client', 'clobber')
        end
        return
      end

      if SiteSetting.scheduled_readonly_notice != ro_message
        SiteSetting.scheduled_readonly_notice = ro_message
      end

      if (must_ro_e || must_ro_w) 
        if SiteSetting.scheduled_readonly_prevent_posting
          if SiteSetting.respond_to?(:prevent_posting_enabled)
            if !SiteSetting.prevent_posting_enabled
              Rails.logger.warn("Enable prevent posting mode #{ro_message}")
              SiteSetting.prevent_posting_enabled = true
            end
          else
            Rails.logger.error("The prevent posting plugin is not installed")
          end
        else
          if (!Discourse.readonly_mode?)
            Rails.logger.warn("Enable readonly mode #{ro_message}")
            Discourse.enable_readonly_mode 
            MessageBus.publish('/refresh_client', 'clobber')
          end
        end
      else
        if SiteSetting.scheduled_readonly_prevent_posting
          if SiteSetting.respond_to?(:prevent_posting_enabled) 
            if SiteSetting.prevent_posting_enabled
              Rails.logger.warn("Disable prevent posting mode #{ro_message}")
              SiteSetting.prevent_posting_enabled = false
            end
          else
            Rails.logger.error("The prevent posting plugin is not installed")
          end
        else
          if (Discourse.readonly_mode?)
            Rails.logger.warn("Disable readonly mode")
            Discourse.disable_readonly_mode 
            MessageBus.publish('/refresh_client', 'clobber')
          end
        end
      end
    end
  end
end
