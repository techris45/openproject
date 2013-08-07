Given /^there is a news "(.+)" for project "(.+)"$/ do |news_title, project_name|

  project = Project.find_by_name(project_name)
  project.news.create!(title: news_title, description: "lorem ipsum")

end

Then /^there should be (\d+) news$/ do |count|
  News.count.should eql count.to_i
end

Then /^there should be (\d+) news for project "(.+)"$/ do |count, project_name|
  project = Project.find_by_name(project_name)
  project.news.count.should eql count.to_i
end

When(/^I should not see the news-headline "([^"]*)"$/) do |news_headline|
  page.should_not have_css("#widget_news .news .overview a", text: news_headline)
end

When(/^I should see the news-headline "([^"]*)"$/) do |news_headline|
  page.should have_css("#widget_news .news .overview a", text: news_headline)
end


# steps for issues reported by me
def reported_issue_subject
  "#widget_issuesreportedbyme td.subject a"
end

When /^I should see the issue-subject "([^"]*)" in the 'Issues reported by me'-section$/ do |issue_subject|
  page.should have_css(reported_issue_subject, text: issue_subject)
end

When /^I should not see the issue-subject "([^"]*)" in the 'Issues reported by me'-section$/ do |issue_subject|
  page.should_not have_css(reported_issue_subject, text: issue_subject)
end

# steps for issues assigned to me
def assigned_to_me_issue_subject
  "#widget_issuesassignedtome td.subject a"
end

When /^I should see the issue-subject "([^"]*)" in the 'Issues assigned to me'-section$/ do |issue_subject|
  page.should have_css(assigned_to_me_issue_subject, text: issue_subject)
end

When /^I should not see the issue-subject "([^"]*)" in the 'Issues assigned to me'-section$/ do |issue_subject|
  page.should_not have_css(assigned_to_me_issue_subject, text: issue_subject)
end


# steps for issues assigned to me
def watched_issue_subject
  "#widget_issueswatched td.subject a"
end

When /^I should see the issue-subject "([^"]*)" in the 'Issues watched'-section$/ do |issue_subject|
  page.should have_css(watched_issue_subject, text: issue_subject)
end

When /^I should not see the issue-subject "([^"]*)" in the 'Issues watched'-section$/ do |issue_subject|
  page.should_not have_css(watched_issue_subject, text: issue_subject)
end


Given /^the [Uu]ser "([^\"]*)" has (\d+) [iI]ssue(?:s)? for the project "([^\"]*)" with(?: the following)?:$/ do |user, count, project_name, table|
  u = User.find_by_login user
  project = Project.find_by_name(project_name)

  raise "This user must be member of the project to have issues" unless u.projects.map(&:id).include? project.id
  as_admin count do
    i = Issue.generate_for_project!(project)
    i.author = u
    i.assigned_to = u
    i.type = Type.find_by_name(table.rows_hash.delete("type")) if table.rows_hash["type"]
    send_table_to_object(i, table, {}, method(:add_custom_value_to_issue))
    i.save!
  end
end
