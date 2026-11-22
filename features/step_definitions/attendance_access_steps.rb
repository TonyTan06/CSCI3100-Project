
Given("I am logged in as an organizer of one organization") do
  @own_organization = Organization.create!(
    name: "BDD Organization A"
  )

  @organizer = User.create!(
    email_address: "bdd_organizer@example.com",
    password: "password123",
    role: "organizer",
    organization: @own_organization
  )

  visit new_session_path

  fill_in "Email Address", with: @organizer.email_address
  fill_in "Password", with: "password123"

  click_button "Sign in"

  unless page.has_button?("Sign Out")
    raise "Organizer login failed"
  end
end

Given("another organization has a shift with confirmed volunteers") do
  @other_organization = Organization.create!(
    name: "BDD Organization B"
  )

  @other_activity = Activity.create!(
    organization: @other_organization,
    title: "Community Cleanup",
    description: "Help clean the community",
    location: "Community Center"
  )

  start_time = 7.days.from_now.change(hour: 9, min: 0, sec: 0)

  @other_shift = Shift.create!(
    activity: @other_activity,
    start_time: start_time,
    end_time: start_time + 2.hours,
    capacity: 2
  )

  @other_shift.capacity.times do |index|
    volunteer = User.create!(
      email_address: "bdd_other_volunteer_#{index + 1}@example.com",
      password: "password123",
      role: "volunteer"
    )

    signup = SignupService.call(
      user: volunteer,
      shift: @other_shift
    )

    unless signup.persisted? && signup.status == "confirmed"
      raise "Expected the other organization's signup to be confirmed"
    end
  end

  unless @other_shift.reload.confirmed_count == 2
    raise "Expected two confirmed volunteers in the other organization"
  end
end

When("I visit the other organization's attendance page") do
  visit activity_shift_attendances_path(@other_activity, @other_shift)
end

Then("the attendance request should return {int}") do |expected_status|
  actual_status = page.status_code

  unless actual_status == expected_status
    raise "Expected HTTP #{expected_status}, but got HTTP #{actual_status}"
  end
end

Given("my organization has a shift with confirmed volunteers") do
  @own_activity = Activity.create!(
    organization: @own_organization,
    title: "Campus Volunteer Day",
    description: "Help organize a campus event",
    location: "CUHK Campus"
  )

  start_time = 7.days.from_now.change(hour: 9, min: 0, sec: 0)

  @own_shift = Shift.create!(
    activity: @own_activity,
    start_time: start_time,
    end_time: start_time + 2.hours,
    capacity: 2
  )

  @own_shift.capacity.times do |index|
    volunteer = User.create!(
      email_address: "bdd_own_volunteer_#{index + 1}@example.com",
      password: "password123",
      role: "volunteer"
    )

    signup = SignupService.call(
      user: volunteer,
      shift: @own_shift
    )

    unless signup.persisted? && signup.status == "confirmed"
      raise "Expected own organization's signup to be confirmed"
    end
  end

  unless @own_shift.reload.confirmed_count == 2
    raise "Expected two confirmed volunteers in my organization"
  end
end

When("I visit my organization's attendance page") do
  visit activity_shift_attendances_path(@own_activity, @own_shift)
end

When("I visit the attendance page for the shift") do
  visit activity_shift_attendances_path(@activity, @shift)
end
