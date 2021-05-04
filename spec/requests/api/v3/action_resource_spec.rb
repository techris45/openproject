#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2012-2021 the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
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
# See docs/COPYRIGHT.rdoc for more details.
#++

require 'spec_helper'
require 'rack/test'

describe 'API v3 action resource', type: :request, content_type: :json do
  include Rack::Test::Methods
  include API::V3::Utilities::PathHelper

  subject(:response) { last_response }

  current_user do
    FactoryBot.create(:user)
  end

  describe 'GET api/v3/actions' do
    let(:path) { api_v3_paths.actions }

    before do
      get path
    end

    it 'returns a collection of actions' do
      expect(subject.body)
        .to be_json_eql(Action.count.to_json)
        .at_path('total')

      expect(subject.body)
        .to be_json_eql(Action.order(id: :asc).first.id.to_json)
        .at_path('_embedded/elements/0/id')

      expect(subject.body)
        .to be_json_eql(Action.order(id: :asc).first.id.to_json)
        .at_path("_embedded/elements/0/id")
    end
  end

  describe 'GET /api/v3/actions/:id' do
    let(:path) { api_v3_paths.action("memberships/create") }

    before do
      get path
    end

    it 'returns 200 OK' do
      expect(subject.status)
        .to eql(200)
    end

    it 'returns the action' do
      expect(subject.body)
        .to be_json_eql('Action'.to_json)
        .at_path('_type')

      expect(subject.body)
        .to be_json_eql("memberships/create".to_json)
        .at_path('id')
    end

    context 'with an action that has an underscore' do
      let(:path) { api_v3_paths.action("work_packages/read") }

      it 'returns 200 OK' do
        expect(subject.status)
          .to eql(200)
      end

      it 'returns the action' do
        expect(subject.body)
          .to be_json_eql('Action'.to_json)
                .at_path('_type')

        expect(subject.body)
          .to be_json_eql("work_packages/read".to_json)
                .at_path('id')
      end
    end

    context 'if querying a non existing action' do
      let(:path) { api_v3_paths.action("foo/bar") }

      it 'returns 404 NOT FOUND' do
        expect(subject.status)
          .to be 404
      end
    end

    context 'if querying with malformed id' do
      let(:path) { api_v3_paths.action("foobar") }

      it 'returns 404 NOT FOUND' do
        expect(subject.status)
          .to be 404
      end
    end
  end
end
