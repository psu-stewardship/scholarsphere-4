# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Search Facets', :inline_jobs do
  describe 'renaming a user updates their Creator facet' do
    let(:my_actor) { build :actor, default_alias: 'Me Before Rename' }

    let(:another_actor) { build :actor, default_alias: 'Someone Else' }

    before do
      # A work I'm a creator on
      my_work_version = create(:work_version, :published, title: 'A Work I Created', creator_count: 0, creators: [my_actor])

      # A collection I'm a creator on
      create(:collection, title: 'A Collection I Created', creators: [my_actor], works: [my_work_version.work])

      # A work someone else created
      create(:work_version, :published, title: 'A Work Someone Else Created', creators: [another_actor])
    end

    it 'updates the facet (but not the resource) when an actor changes their default alias' do
      visit search_catalog_path
      click_button('Search')

      # Sanity Check
      within '#documents' do
        expect(page).to have_content('Me Before Rename')
        expect(page).to have_content('Someone Else')
      end
      within '#facets' do
        expect(page).to have_content('Me Before Rename')
        expect(page).to have_content('Someone Else')
      end

      # Update my default alias
      my_actor.update(default_alias: 'Me After Rename')

      click_button('Search')

      # Documents retain the original alias from when the resource was created
      within '#documents' do
        expect(page).not_to have_content('Me After Rename')
        expect(page).to have_content('Me Before Rename')
        expect(page).to have_content('Someone Else')
      end

      # Facets are "Canonized" to the Actor's default_alias
      within '#facets' do
        expect(page).to have_content('Me After Rename')
        expect(page).not_to have_content('Me Before Rename')
        expect(page).to have_content('Someone Else')
      end

      # Make sure facets actually work
      within('#facets') { click_link 'Me After Rename' }
      within '#documents' do
        expect(page).to have_content 'A Work I Created'
        expect(page).to have_content 'A Collection I Created'
        expect(page).not_to have_content 'A Work Someone Else Created'
      end
    end
  end
end