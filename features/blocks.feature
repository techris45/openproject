Feature: Behavior of specific blocks (news, issues - this is currently not complete!!)
  Background:
    Given there is 1 project with the following:
      | name        | tested_project      |
    And the project "tested_project" has the following types:
      | name | position |
      | Bug  |     1    |
    And there is 1 project with the following:
      | name        | other_project      |
    And the project "other_project" has the following types:
      | name | position |
      | Bug  |     1    |
    And there is 1 user with the following:
      | login      | bob      |
    And there is 1 user with the following:
      | login      | mary      |
    And there is a role "member"
    And the role "member" may have the following rights:
      | view_work_packages |
      | create_issues |
    And the user "bob" is a "member" in the project "tested_project"
    And the user "bob" is a "member" in the project "other_project"
    And I am logged in as "bob"



  Scenario: In the news Section, I should only see news for the selected project
    And project "tested_project" uses the following modules:
      | news |
    And the following widgets should be selected for the overview page of the "tested_project" project:
      #TODO mapping from the human-name back to it's widget-name??!
      | top        | news   |
    Given there is a news "test-headline" for project "tested_project"
    And there is a news "NO-SHOW" for project "other_project"
    And I am on the project "tested_project" overview page
    Then I should see the widget "news"
    And I should see the news-headline "test-headline"
    And I should not see the news-headline "NO-SHOW"

  Scenario: In the 'Issues reported by me'-Section, I should only see issues for the selected project
    And the user "bob" has 1 Issue for the project "tested_project" with:
      | subject    | Test-Issue  |
    And the user "bob" has 1 Issue for the project "other_project" with:
      | subject    | NO-SHOW      |
    And the following widgets should be selected for the overview page of the "tested_project" project:
      | top        | issuesreportedbyme |
    And I am on the project "tested_project" overview page
    Then I should see the widget "issuesreportedbyme"
    And I should see the issue-subject "Test-Issue" in the 'Issues reported by me'-section
    And I should not see the issue-subject "NO-SHOW" in the 'Issues reported by me'-section

  Scenario: In the 'Issues assigned to me'-Section, I should only see issues for the selected project
    And the user "bob" has 1 Issue for the project "tested_project" with:
      | subject    | Test-Issue  |
    And the user "bob" has 1 Issue for the project "other_project" with:
      | subject    | NO-SHOW      |
    And the following widgets should be selected for the overview page of the "tested_project" project:
      | top        | issuesassignedtome |
    And I am on the project "tested_project" overview page
    Then I should see the widget "issuesassignedtome"
    And I should see the issue-subject "Test-Issue" in the 'Issues assigned to me'-section
    And I should not see the issue-subject "NO-SHOW" in the 'Issues assigned to me'-section

  Scenario: In the 'Issues watched by me'-Section, I should only see issues for the selected project
    And the user "bob" has 1 Issue for the project "tested_project" with:
      | subject    | Test-Issue  |
    And the issue "Test-Issue" is watched by:
      | bob |
    And the user "bob" has 2 Issue for the project "other_project" with:
      | subject    | NOT-WATCHED      |
    And the issue "NOT-WATCHED" is watched by:
      | bob |
    And the following widgets should be selected for the overview page of the "tested_project" project:
      | top        | issueswatched |
    And I am on the project "tested_project" overview page
    Then I should see the widget "issueswatched"
    And I should see the issue-subject "Test-Issue" in the 'Issues watched'-section
    And I should not see the issue-subject "NOT-WATCHED" in the 'Issues watched'-section
