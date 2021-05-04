#-- encoding: UTF-8

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

class ProjectsController < ApplicationController
  menu_item :overview
  menu_item :roadmap, only: :roadmap

  before_action :find_project, except: %i[index level_list new]
  before_action :authorize, only: %i[modules types custom_fields copy]
  before_action :authorize_global, only: %i[new]
  before_action :require_admin, only: %i[archive unarchive destroy destroy_info]

  include SortHelper
  include PaginationHelper
  include CustomFieldsHelper
  include QueriesHelper
  include RepositoriesHelper
  include ProjectsHelper

  # Lists visible projects
  def index
    query = load_query

    unless query.valid?
      flash[:error] = query.errors.full_messages
    end

    @projects = load_projects query
    @orders = set_sorting query

    render layout: 'no_menu'
  end

  current_menu_item :index do
    :list_projects
  end

  def new
    render layout: 'no_menu'
  end

  def update
    @altered_project = Project.find(@project.id)

    service_call = Projects::UpdateService
      .new(user: current_user,
           model: @altered_project)
      .call(permitted_params.project)

    if service_call.success?
      flash[:notice] = t(:notice_successful_update)
      redirect_to settings_generic_project_path(@altered_project)
    else
      @errors = service_call.errors
      render template: 'project_settings/generic'
    end
  end

  def copy
    render
  end

  def update_identifier
    service_call = Projects::UpdateService
      .new(user: current_user,
           model: @project)
      .call(permitted_params.project)

    if service_call.success?
      flash[:notice] = I18n.t(:notice_successful_update)
      redirect_to settings_generic_project_path(@project)
    else
      render action: 'identifier'
    end
  end

  def types
    if UpdateProjectsTypesService.new(@project).call(permitted_params.projects_type_ids)
      flash[:notice] = I18n.t('notice_successful_update')
    else
      flash[:error] = @project.errors.full_messages
    end

    redirect_to settings_types_project_path(@project.identifier)
  end

  def modules
    @project.enabled_module_names = permitted_params.project[:enabled_module_names]
    # Ensure the project is touched to update its cache key
    @project.touch
    flash[:notice] = I18n.t(:notice_successful_update)
    redirect_to settings_modules_project_path(@project)
  end

  def custom_fields
    Project.transaction do
      @project.work_package_custom_field_ids = permitted_params.project[:work_package_custom_field_ids]
      if @project.save
        flash[:notice] = t(:notice_successful_update)
      else
        flash[:error] = t(:notice_project_cannot_update_custom_fields,
                          errors: @project.errors.full_messages.join(', '))
        raise ActiveRecord::Rollback
      end
    end
    redirect_to settings_custom_fields_project_path(@project)
  end

  def archive
    change_status_action(:archive)
  end

  def unarchive
    change_status_action(:unarchive)
  end

  # Delete @project
  def destroy
    service_call = ::Projects::ScheduleDeletionService
      .new(user: current_user, model: @project)
      .call

    if service_call.success?
      flash[:notice] = I18n.t('projects.delete.scheduled')
    else
      flash[:error] = I18n.t('projects.delete.schedule_failed', errors: service_call.errors.full_messages.join("\n"))
    end

    redirect_to project_path_with_status
    update_demo_project_settings @project, false
  end

  def destroy_info
    @project_to_destroy = @project

    hide_project_in_layout
  end

  def level_list
    projects = Project.project_level_list(Project.visible)

    respond_to do |format|
      format.json { render json: projects_level_list_json(projects) }
    end
  end

  ##
  # Redirect as action as routes can only redirect by full path
  def settings
    redirect_to settings_generic_project_path(@project)
  end

  private

  def find_optional_project
    return true unless params[:id]

    @project = Project.find(params[:id])
    authorize
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def change_status_action(status)
    service_call = change_status(status)

    if service_call.success?
      update_demo_project_settings @project, status == :archive
      redirect_to(project_path_with_status)
    else
      flash[:error] = t(:"error_can_not_#{status}_project",
                        errors: service_call.errors.full_messages.join(', '))
      redirect_back fallback_location: project_path_with_status
    end
  end

  def change_status(status)
    "Projects::#{status.to_s.camelcase}Service"
      .constantize
      .new(user: current_user, model: @project)
      .call
  end

  def redirect_work_packages_or_overview
    return if redirect_to_project_menu_item(@project, :work_packages)

    redirect_to project_overview_path(@project)
  end

  def hide_project_in_layout
    @project = nil
  end

  def project_path_with_status
    acceptable_params = params.permit(:status).to_h.compact.select { |_, v| v.present? }

    projects_path(acceptable_params)
  end

  def load_query
    @query = ParamsToQueryService.new(Project, current_user).call(params)

    # Set default filter on status no filter is provided.
    @query.where('active', '=', OpenProject::Database::DB_VALUE_TRUE) unless params[:filters]

    # Order lft if no order is provided.
    @query.order(lft: :asc) unless params[:sortBy]

    @query
  end

  protected

  def load_projects(query)
    query
      .results
      .with_required_storage
      .with_latest_activity
      .includes(:custom_values, :enabled_modules)
      .paginate(page: page_param, per_page: per_page_param)
  end

  def set_sorting(query)
    query.orders.select(&:valid?).map { |o| [o.attribute.to_s, o.direction.to_s] }
  end

  def update_demo_project_settings(project, value)
    # e.g. when one of the demo projects gets deleted or a archived
    if project.identifier == 'your-scrum-project' || project.identifier == 'demo-project'
      Setting.demo_projects_available = value
    end
  end
end
