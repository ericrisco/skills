# Hotwire worked examples

Turbo 8 + Stimulus, the Rails 8 default front-end. Reach for the lightest layer that
solves the problem: Drive → Frame → Stream → morph, and Stimulus only for behavior.

## Turbo Frame — scoped replacement

A frame replaces just its own contents on navigation/submit. Wrap the region and give
matching IDs.

```erb
<%# app/views/posts/show.html.erb %>
<turbo-frame id="post_title">
  <h1><%= @post.title %></h1>
  <%= link_to "Edit", edit_post_path(@post) %>
</turbo-frame>
```

```erb
<%# edit.html.erb — same frame id, so only this swaps in %>
<turbo-frame id="post_title">
  <%= form_with model: @post do |f| %>
    <%= f.text_field :title %>
    <%= f.submit %>
  <% end %>
</turbo-frame>
```

## Turbo Stream — targeted multi-element update

After a create/destroy, return a `.turbo_stream` template to append/replace/remove
specific DOM nodes. The controller responds to the format:

```ruby
def create
  @comment = @post.comments.create!(comment_params)
  respond_to do |format|
    format.turbo_stream
    format.html { redirect_to @post }
  end
end
```

```erb
<%# create.turbo_stream.erb %>
<%= turbo_stream.append "comments", @comment %>
<%= turbo_stream.update "comments_count", @post.comments.count %>
```

## Broadcasting from a model

Push updates to every subscribed browser over Solid Cable — no controller round-trip.

```ruby
class Comment < ApplicationRecord
  belongs_to :post
  broadcasts_to ->(comment) { [comment.post, :comments] }
end
```

```erb
<%# in show.html.erb, subscribe the page %>
<%= turbo_stream_from @post, :comments %>
<div id="comments"><%= render @post.comments %></div>
```

`broadcasts_to` fires append-on-create / replace-on-update / remove-on-destroy to that
stream automatically.

## Morphing — full refresh, kept scroll

Turbo 8 can re-render the whole page and morph the DOM diff while preserving scroll and
focus. Enable it in the layout:

```erb
<%= turbo_refreshes_with method: :morph, scroll: :preserve %>
```

Now a plain `redirect_to` / page refresh updates in place without bespoke Stream
choreography. Use an explicit Stream only when morphing can't infer the change (e.g.
prepend a row from a background broadcast).

## Stimulus — values, targets, outlets, actions

```javascript
// app/javascript/controllers/filter_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["query", "results"]
  static values  = { url: String, debounce: { type: Number, default: 300 } }
  static outlets  = ["toast"]

  connect() { this.timer = null }

  search() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.#fetch(), this.debounceValue)
  }

  async #fetch() {
    const res = await fetch(`${this.urlValue}?q=${this.queryTarget.value}`)
    this.resultsTarget.innerHTML = await res.text()
    this.toastOutlet?.show("Updated")   // call another controller via outlet
  }
}
```

```erb
<div data-controller="filter" data-filter-url-value="<%= search_path %>">
  <input data-filter-target="query" data-action="input->filter#search">
  <div data-filter-target="results"></div>
</div>
```

- **values** — typed, reactive config from data attributes.
- **targets** — element references inside the controller's scope.
- **outlets** — call methods on another controller's instance.
- **actions** — `event->controller#method` wiring.

## System-testing Turbo interactions

Capybara matchers auto-wait, so they survive Turbo's async DOM updates. Never `sleep`.

```ruby
class CommentsTest < ApplicationSystemTestCase
  test "comment appears live" do
    visit post_path(posts(:one))
    fill_in "Comment", with: "Nice post"
    click_on "Post comment"
    assert_text "Nice post"          # retries until the Stream lands
    assert_selector "#comments .comment", count: 1
  end
end
```

If the page uses broadcasts, ensure the test driver runs the Action Cable/Solid Cable
connection (default config does). For driver choice and flake-hardening, see
`testing.md`.
