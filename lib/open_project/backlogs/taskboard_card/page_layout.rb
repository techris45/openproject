#-- copyright
# OpenProject Backlogs Plugin
#
# Copyright (C)2013 the OpenProject Team
# Copyright (C)2011 Stephan Eckardt, Tim Felgentreff, Marnen Laibow-Koser, Sandro Munda
# Copyright (C)2010-2011 friflaj
# Copyright (C)2010 Maxime Guilbot, Andrew Vit, Joakim Kolsjö, ibussieres, Daniel Passos, Jason Vasquez, jpic, Emiliano Heyns
# Copyright (C)2009-2010 Mark Maglana
# Copyright (C)2009 Joe Heck, Nate Lowrie
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License version 3.
#
# OpenProject Backlogs is a derivative work based on ChiliProject Backlogs.
# The copyright follows:
# Copyright (C) 2010-2011 - Emiliano Heyns, Mark Maglana, friflaj
# Copyright (C) 2011 - Jens Ulferts, Gregor Schmidt - Finn GmbH - Berlin, Germany
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See doc/COPYRIGHT.rdoc for more details.
#++

require 'net/http'
require 'rexml/document'

require 'yaml'
require 'uri/common'

require 'prawn'

module OpenProject::Backlogs::TaskboardCard
  class PageLayout
    unloadable

    include Measurement

    LABELS_FILE_NAME = File.join(File.dirname(__FILE__), '../../../..', 'config', 'labels.yml')
    MALFORMED_LABELS_FILE_NAME = File.join(File.dirname(__FILE__), '../../../..', 'config', 'labels-malformed.yml')

    if File.exist? LABELS_FILE_NAME
      LABELS = YAML::load_file(LABELS_FILE_NAME)
    else
      puts "Using default card label dimensions. Be sure to run " +
           "`rake redmine:backlogs:current_labels` to get current definitions " +
           "from git.gnome.org."
      LABELS = YAML::load_file(LABELS_FILE_NAME + '.default')
    end

    class << self
      def available?
        selected_label.present?
      end

      def selected_label
        LABELS[Setting.plugin_openproject_backlogs["card_spec"]]
      end

      def measurement(x)
        x = "#{x}pt" if x =~ /[0-9]$/
        x
      end

      def malformed?(label)
        to_pts(label['height']) > to_pts(label['vertical_pitch']) ||
          to_pts(label['width']) > to_pts(label['horizontal_pitch'])
      end

      def fetch_labels
        LABELS.clear

        malformed_labels = {}

        fetched_templates.each do |filename|
          uri = URI.parse("http://git.gnome.org/browse/glabels/plain/templates/#{filename}")
          labels = nil

          if ENV['http_proxy'].present?
            begin
              proxy = URI.parse(ENV['http_proxy'])
              if proxy.userinfo
                user, pass = proxy.userinfo.split(/:/)
              else
                user = pass = nil
              end
              labels = Net::HTTP::Proxy(proxy.host, proxy.port, user, pass).start(uri.host) {|http| http.get(uri.path)}.body
            rescue URI::Error => e
              puts "Setup proxy failed: #{e}"
              labels = nil
            end
          end

          begin
            labels = Net::HTTP.get_response(uri).body if labels.nil?
          rescue
            labels = nil
          end

          if labels.nil?
            puts "Could not fetch #{filename}"
            next
          end

          doc = REXML::Document.new(labels)

          doc.elements.each('Glabels-templates/Template') do |specs|
            label = nil

            papersize = specs.attributes['size']
            papersize = 'Letter' if papersize == 'US-Letter'

            specs.elements.each('Label-rectangle') do |geom|
              margin = nil
              geom.elements.each('Markup-margin') do |m|
                  margin = m.attributes['size']
              end
              margin = "1mm" if margin.blank?

              geom.elements.each('Layout') do |layout|
                label = {
                  'inner_margin'     => PageLayout.measurement(margin),
                  'across'           => Integer(layout.attributes['nx']),
                  'down'             => Integer(layout.attributes['ny']),
                  'top_margin'       => PageLayout.measurement(layout.attributes['y0']),
                  'height'           => PageLayout.measurement(geom.attributes['height']),
                  'horizontal_pitch' => PageLayout.measurement(layout.attributes['dx']),
                  'left_margin'      => PageLayout.measurement(layout.attributes['x0']),
                  'width'            => PageLayout.measurement(geom.attributes['width']),
                  'vertical_pitch'   => PageLayout.measurement(layout.attributes['dy']),
                  'papersize'        => papersize,
                  'source'           => 'glabel'
                }
              end
            end

            next if label.nil? || label['across'] != 1 || label['down'] != 1 || label['papersize'].downcase == 'other'

            key = "#{specs.attributes['brand']} #{specs.attributes['part']}"

            if PageLayout.malformed?(label)
              puts "Skipping malformed label '#{key}' from #{filename}"
              malformed_labels[key] = label
            else
              LABELS[key] = label if not LABELS[key] or LABELS[key]['source'] == 'glabel'

              specs.elements.each('Alias') do |also|
                key = "#{also.attributes['brand']} #{also.attributes['part']}"
                LABELS[key] = label.dup if not LABELS[key] or LABELS[key]['source'] == 'glabel'
              end
            end
          end
        end

        File.open(LABELS_FILE_NAME, 'w') do |dump|
          YAML.dump(LABELS, dump)
        end
        File.open(MALFORMED_LABELS_FILE_NAME, 'w') do |dump|
          YAML.dump(malformed_labels, dump)
        end

        if Setting.plugin_openproject_backlogs["card_spec"] && ! PageLayout.selected_label && LABELS.size != 0
          # current label non-existant
          label = LABELS.keys[0]
          puts "Non-existant label stock '#{Setting.plugin_openproject_backlogs["card_spec"]}' selected, replacing with random '#{label}'"
          s = Setting.plugin_openproject_backlogs
          s["card_spec"] = label
          Setting.plugin_openproject_backlogs = s
        end
      end

      def fetched_templates
        ['avery-iso-templates.xml',
         'avery-other-templates.xml',
         'avery-us-templates.xml',
         'brother-other-templates.xml',
         'dymo-other-templates.xml',
         'maco-us-templates.xml',
         'misc-iso-templates.xml',
         'misc-other-templates.xml',
         'misc-us-templates.xml',
         'pearl-iso-templates.xml',
         'uline-us-templates.xml',
         'worldlabel-us-templates.xml',
         'zweckform-iso-templates.xml']
      end
    end
  end
end
