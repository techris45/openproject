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

require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe WorkPackage do
  describe :backlogs_types do
    it "should return all the ids of types that are configures to be considered backlogs types" do
      Setting.stub(:plugin_openproject_backlogs).and_return({"story_types" => [1], "task_type" => 2})

      WorkPackage.backlogs_types.should =~ [1,2]
    end

    it "should return an empty array if nothing is defined" do
      Setting.stub(:plugin_openproject_backlogs).and_return({})

      WorkPackage.backlogs_types.should == []
    end

    it 'should reflect changes to the configuration' do
      Setting.stub(:plugin_openproject_backlogs).and_return({"story_types" => [1], "task_type" => 2})
      WorkPackage.backlogs_types.should =~ [1,2]

      Setting.stub(:plugin_openproject_backlogs).and_return({"story_types" => [3], "task_type" => 4})
      WorkPackage.backlogs_types.should =~ [3,4]
    end
  end
end
