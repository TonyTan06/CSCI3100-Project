
Given("I am logged in as a volunteer") do
  @volunteer = User.create!(
    email_address: "bdd_volunteer@example.com",
    password: "password123",
    role: "volunteer"
  )

  visit new_session_path

  fill_in "Email Address", with: @volunteer.email_address
  fill_in "Password", with: "password123"

  click_button "Sign in"

  raise "Volunteer login failed" if page.has_current_path?(new_session_path)
end

Given("there is a shift with an available spot") do
  @organization = Organization.create!(
    name: "BDD Volunteer Team"
  )

  @activity = Activity.create!(
    organization: @organization,
    title: "Campus Cleanup",
    description: "Help clean the campus",
    location: "CUHK Campus"
  )

  start_time = 7.days.from_now.change(hour: 9, min: 0, sec: 0)

  @shift = Shift.create!(
    activity: @activity,
    start_time: start_time,
    end_time: start_time + 2.hours,
    capacity: 2
  )
end

Given("I have a confirmed signup for an overlapping shift") do
  @overlapping_shift = Shift.create!(
    activity: @activity,
    start_time: @shift.start_time + 1.hour,
    end_time: @shift.end_time + 1.hour,
    capacity: 2
  )

  @existing_signup = SignupService.call(
    user: @volunteer,
    shift: @overlapping_shift
  )

  unless @existing_signup.persisted? && @existing_signup.status == "confirmed"
    raise "Expected overlapping shift signup to be confirmed"
  end
end

Given("the shift has reached capacity") do
  @shift.capacity.times do |index|
    volunteer = User.create!(
      email_address: "bdd_existing_volunteer_#{index + 1}@example.com",
      password: "password123",
      role: "volunteer"
    )

    signup = SignupService.call(
      user: volunteer,
      shift: @shift
    )

    unless signup.persisted? && signup.status == "confirmed"
      raise "Expected existing volunteer signup to be confirmed"
    end
  end

  unless @shift.reload.full?
    raise "Expected shift to be full"
  end
end

When("I sign up for the shift") do
  visit activity_shift_path(@activity, @shift)

  click_button "Sign Up"
end

When("I join the waitlist") do
  visit activity_shift_path(@activity, @shift)

  click_button "Join Waitlist"
end

When("a confirmed volunteer cancels their signup") do
  @cancelled_signup = @shift.signups.find_by!(status: "confirmed")
  confirmed_volunteer = @cancelled_signup.user

  # Sign out the waitlisted volunteer
  click_button "Sign Out"

  # Sign in as an existing confirmed volunteer
  visit new_session_path

  fill_in "Email Address", with: confirmed_volunteer.email_address
  fill_in "Password", with: "password123"

  click_button "Sign in"

  raise "Confirmed volunteer login failed" if page.has_current_path?(new_session_path)

  # Cancel the confirmed signup through the Shift page
  visit activity_shift_path(@activity, @shift)

  click_button "Cancel Signup"

  # Sign out the confirmed volunteer
  click_button "Sign Out"

  # Sign back in as the original waitlisted volunteer
  visit new_session_path

  fill_in "Email Address", with: @volunteer.email_address
  fill_in "Password", with: "password123"

  click_button "Sign in"

  raise "Original volunteer login failed" if page.has_current_path?(new_session_path)

  visit activity_shift_path(@activity, @shift)
end

Then("my signup should be confirmed") do
  signup = @shift.signups.find_by!(user: @volunteer)

  unless signup.status == "confirmed"
    raise "Expected confirmed signup, but got #{signup.status}"
  end

  within("#my-signup") do
    unless has_css?(".status-confirmed", text: "Confirmed")
      raise "Confirmed signup status is not displayed"
    end
  end
end

Then("my signup should be waitlisted") do
  signup = @shift.signups.find_by!(user: @volunteer)

  unless signup.status == "waitlisted"
    raise "Expected waitlisted signup, but got #{signup.status}"
  end

  unless @shift.reload.confirmed_count == @shift.capacity
    raise "Shift confirmed count does not match capacity"
  end

  within("#my-signup") do
    unless has_css?(".status-waitlisted", text: "Waitlisted")
      raise "Waitlisted signup status is not displayed"
    end

    unless has_css?(".shift-waitlist-position", text: "1 of 1")
      raise "Expected waitlist position 1 of 1"
    end
  end
end

Then("my signup should be promoted to confirmed") do
  # Verify the original confirmed signup was cancelled
  unless @cancelled_signup.reload.status == "cancelled"
    raise "Expected the original signup to be cancelled"
  end

  # Verify the waitlisted volunteer was promoted
  signup = @shift.signups.find_by!(user: @volunteer)

  unless signup.status == "confirmed"
    raise "Expected promoted signup to be confirmed, but got #{signup.status}"
  end

  # Verify the shift capacity remains correct
  @shift.reload

  unless @shift.confirmed_count == @shift.capacity
    raise "Expected shift capacity to be filled after promotion"
  end

  unless @shift.waitlist_queue.count == 0
    raise "Expected no volunteers remaining on the waitlist"
  end

  # Verify the promoted status is visible on the page
  within("#my-signup") do
    unless has_css?(".status-confirmed", text: "Confirmed")
      raise "Promoted volunteer's confirmed status is not displayed"
    end
  end
end

Then("the overlapping signup should be rejected") do
  # Verify no signup was created for the conflicting shift
  conflicting_signup = @shift.signups.find_by(user: @volunteer)

  if conflicting_signup
    raise "Expected overlapping signup to be rejected, but a signup was created"
  end

  # Verify the existing confirmed signup remains unchanged
  unless @existing_signup.reload.status == "confirmed"
    raise "Expected the existing signup to remain confirmed"
  end

  # Verify the target shift still has no confirmed signups
  unless @shift.reload.confirmed_count == 0
    raise "Expected no confirmed signups for the conflicting shift"
  end

  # Verify the user sees a time conflict error
  unless page.has_text?(/overlap|conflict/i)
    raise "Expected a time conflict error message to be displayed"
  end
end
