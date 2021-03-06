module Plugins::CamaContactForm::MainHelper
  include Recaptcha::Adapters::ViewMethods
  def self.included(klass)
    klass.helper_method [:cama_form_element_bootstrap_object, :cama_form_shortcode] rescue "" # here your methods accessible from views
  end

  def contact_form_on_export(args)
    args[:obj][:plugins][self_plugin_key] = JSON.parse(current_site.contact_forms.to_json(:include => [:responses]))
  end

  def contact_form_on_import(args)
    plugins = args[:data][:plugins]
    if plugins[self_plugin_key.to_sym].present?
      plugins[self_plugin_key.to_sym].each do |contact|
        unless current_site.contact_forms.where(slug: contact[:slug]).first.present?
          sba_data = ActionController::Parameters.new(contact)
          contact_new = current_site.contact_forms.new(sba_data.permit(:name, :slug, :count, :description, :value, :settings))
          if contact_new.save!
            if contact[:get_field_groups] # save group fields
              save_field_group(contact_new, contact[:get_field_groups])
            end
            save_field_values(contact_new, contact[:field_values])

            if contact[:responses].present? # saving responses for this contact
              contact[:responses].each do |response|
                sba_data = ActionController::Parameters.new(response)
                contact_new.responses.create!(sba_data.permit(:name, :slug, :count, :description, :value, :settings))
              end
            end
            args[:messages] << "Saved Plugin Contact Form: #{contact_new.name}"
          end
        end
      end
    end
  end

  # here all actions on plugin destroying
  # plugin: plugin model
  def contact_form_on_destroy(plugin)

  end

  # here all actions on going to active
  # you can run sql commands like this:
  # results = ActiveRecord::Base.connection.execute(query);
  # plugin: plugin model
  def contact_form_on_active(plugin)

  end

  # here all actions on going to inactive
  # plugin: plugin model
  def contact_form_on_inactive(plugin)

  end

  def contact_form_admin_before_load
    admin_menu_append_menu_item("settings", {icon: "envelope-o", title: t('plugins.cama_contact_form.title', default: 'Contact Form'), url: admin_plugins_cama_contact_form_admin_forms_path, datas: "data-intro='This plugin permit you to create you contact forms with desired fields and paste your short_code in any content.' data-position='right'"})
  end

  def contact_form_app_before_load
    shortcode_add('forms', plugin_view("forms_shorcode"), "This is a shortocode for contact form to permit you to put your contact form in any content. Sample: [forms slug='key-for-my-form']")
  end

  def contact_form_front_before_load

  end

  # ============== HTML ==================
  # This returns the format of the plugin shortcode.
  def cama_form_shortcode(slug)
    "[forms slug=#{slug}]"
  end

  # form contact with css bootstrap
  def cama_form_element_bootstrap_object(form, object, values, flash_error = [])
    html = ""
    object.each do |ob|
      ob[:label] = ob[:label].to_s.translate
      ob[:description] = ob[:description].to_s.translate
      r = {field: ob, form: form, template: (ob[:field_options][:template].present? ? ob[:field_options][:template] : Plugins::CamaContactForm::CamaContactForm::field_template), custom_class: (ob[:field_options][:field_class] rescue nil), custom_attrs: {id: ob[:cid] }.merge((JSON.parse(ob[:field_options][:field_attributes]) rescue {})) }
      hooks_run("contact_form_item_render", r)
      ob = r[:field]
      has_error = (flash_error.select { |err| err["field"] == ob[:cid] }).present?
      ob[:custom_class] = r[:custom_class] || " "
      ob[:custom_class] += " has-error" if has_error
      ob[:custom_attrs] = r[:custom_attrs]
      field_options = ob[:field_options]
      for_name = ob[:label].to_s
      if ob[:required].present? && ob[:required].to_bool
        ob[:custom_attrs][:required] = 'true'
        for_name = "#{for_name}<span class=\"field_required\">*</span>"
      end

      f_name = "fields[#{ob[:cid]}]"
      cid = ob[:cid].to_sym

      temp2 = ""

      case ob[:field_type].to_s
        when 'paragraph','textarea'
          temp2 = "<textarea #{ob[:custom_attrs].to_attr_format} name=\"#{f_name}\" maxlength=\"#{field_options[:maxlength] || 500 }\"  class=\"form-control\">#{values[cid] || ob[:default_value].to_s.translate}</textarea>"
        when 'radio'
          temp2=  cama_form_select_multiple_bootstrap(ob, ob[:label], ob[:field_type],values)
        when 'checkboxes'
          temp2=  cama_form_select_multiple_bootstrap(ob, ob[:label], "checkbox", values)
        when 'submit'
          temp2 = "<button #{ob[:custom_attrs].to_attr_format} type=\"#{ob[:field_type]}\" name=\"#{f_name}\"  class=\"btn btn-default\">#{ob[:label]}</button>"
        when 'button'
          temp2 = "<button #{ob[:custom_attrs].to_attr_format} type='button' name=\"#{f_name}\" class=\"btn btn-default\">#{ob[:label]}</button>"
        when 'reset_button'
          temp2 = "<button #{ob[:custom_attrs].to_attr_format} type='reset' name=\"#{f_name}\" class=\"btn btn-default\">#{ob[:label]}</button>"
        when 'text', 'website', 'email'
          class_type = ""
          class_type = "railscf-field-#{ob[:field_type]}" if ob[:field_type]=="website"
          class_type = "railscf-field-#{ob[:field_type]}" if ob[:field_type]=="email"

          blur_func = ""
          blur_func = "v-on:blur=\"onBlurPostcode($event)\"" if ob[:custom_class].to_s.include?('postcode')

          temp2 = "<input #{ob[:custom_attrs].to_attr_format} type=\"#{ob[:field_type]}\" value=\"#{values[cid] || ob[:default_value].to_s.translate}\" name=\"#{f_name}\" class=\"form-control #{class_type}\" #{blur_func}>"
        when 'captcha'
          if form.recaptcha_enabled?
            temp2 = "<vue-recaptcha #{ob[:custom_attrs].to_attr_format} sitekey='#{form.the_settings[:recaptcha_site_key]}'></vue-recaptcha>"
          else
            temp2 = cama_captcha_tag(5, {}, {class: "#{'form-control'} field-captcha required"}.merge(ob[:custom_attrs]))
          end
        when 'file'
          temp2 = "<input multiple=\"multiple\" type=\"file\" value=\"\" name=\"#{f_name}[]\" #{ob[:custom_attrs].to_attr_format} class=\"form-control\">"
        when 'dropdown'
          temp2 = cama_form_select_multiple_bootstrap(ob, ob[:label], "select",values)
        when 'dealer_selector'
          temp2 = "<dealer-selector #{ob[:custom_attrs].to_attr_format} name=\"#{f_name}\"></dealer-selector>"
        when 'dealer_card_picker'
          temp2 = "<dealer-card-picker #{ob[:custom_attrs].to_attr_format} name=\"#{f_name}\"></dealer-card-picker>"
        else
      end
      r[:template] = r[:template].sub('[ci]', temp2)
      r[:template] = r[:template].sub('[descr ci]', field_options[:description].to_s.translate).sub('<p></p>', '')
      r[:template] = r[:template].sub('[cc]', ob[:custom_class].to_s)
      html += r[:template].gsub('[label ci]', for_name)
    end
    html
  end

  def field_action_values(action)
    result = {}
    if action.present?
      items = action.split('::')
      result[:action_type] = items[0]
      result[:matched_value] = items[1]
      result[:selector] = items[2]
    end

    result
  end

  def vuejs_actions(action)
    result = ''
    if action.present?
      items = action.split('::')
      if items[0] == 'onchange'
        result = "v-on:change=\"onChangeInput($event, '#{items[2]}')\""
      end
    end

    result
  end

  def cama_form_select_multiple_bootstrap(ob, title, type, values)
    options = ob[:field_options][:options]
    include_other_option = ob[:field_options][:include_other_option]
    other_input = ""

    f_name = "fields[#{ob[:cid]}]"
    cid = ob[:cid].to_sym
    html = ""

    if type == "radio" || type == "checkbox"
      other_input = (include_other_option)? "<div class=\"#{type}\"> <label for=\"#{ob[:cid]}\"><input id=\"#{ob[:cid]}-other\" type=\"#{type}\" name=\"#{title.downcase}[]\" class=\"\">Other <input type=\"text\" /></label></div>" : " "
    else
      html = "<select #{ob[:custom_attrs].to_attr_format} name=\"#{f_name}\" >"
    end

    options.to_a.each_with_index do |op, idx|
      label = op[:label].translate
      key = label.downcase.gsub(" ", "_")
      key = op[:key] if op[:key].present?
      action = field_action_values(ob[:field_options][:field_actions])
      checked = values[cid].present? && values[cid].include?(key) ? true : op[:checked].to_s.cama_true?

      if type == "radio" || type == "checkbox"
        ob_id = ob[:custom_attrs][:id]
        ob[:custom_attrs][:id] = "#{ob_id}_#{idx}"
        ob[:custom_attrs].delete(:required)
        html += "<div class=\"#{type}\">
                    <label for=\"#{ob[:cid]}_#{idx}\">
                      <input #{vuejs_actions(ob[:field_options][:field_actions]) if key == action[:matched_value]} #{ob[:custom_attrs].to_attr_format} type=\"#{type}\" #{'checked' if checked} name=\"#{f_name}[]\" value=\"#{key}\">
                      #{ERB::Util.h(label)}
                    </label>
                  </div>"
        ob[:custom_attrs][:id] = ob_id
      else
        html += "<option  value=\"#{key}\" #{"selected" if "#{label.downcase.gsub(" ", "_")}" == values[cid] || op[:checked].to_s.cama_true? } >#{label}</option>"
      end
    end

    if type == "radio" || type == "checkbox"
      html += other_input
    else
      html += " </select>"
    end
  end
end
