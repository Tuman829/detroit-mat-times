# Mat Times

A filterable, printable schedule of grappling classes around Metro Detroit, compiled from a community Google Sheet into one static HTML file.

## How it works

`rake build` reads the CSV snapshot in `data/sheet/`, turns it into plain Ruby objects in `lib/`, and renders the ERB views in `app/views/` to `_site/index.html`. CSS and JS are inlined, and there are no runtime dependencies. Every class is in the HTML, and `app/assets/application.js` only shows and hides what's already there.

## Setup

```bash
bundle install
```

Node is only needed to run the JavaScript tests, which use the built-in `node:test`.

## Commands

```bash
bundle exec rake             # all tests, then build
bundle exec rake test        # Ruby tests
bundle exec rake test:js     # JavaScript tests
bundle exec rake build       # write _site/index.html
bundle exec rake sheet:pull  # refresh data/sheet from the Google Sheet
```

## Updating the schedule

Run `rake sheet:pull`, then `rake`, and commit the changed CSVs. The tests check the new data, and the build stops if the sheet introduces a gym it can't link.

- New shorthand gym label: add it to `data/gym_aliases.yml`.
- Wrong or dead gym website: correct it in `data/gym_overrides.yml`, which survives sheet pulls.
- Support link, site title and theme: `config/site.yml`.

## Themes

Each file in `app/assets/themes/` is a complete look. To switch, change `theme` in `config/site.yml` and rebuild. To add one, drop in a new CSS file. A file named `theme.scheme.css` is a color scheme layered over `theme.css`. `rake themes` builds them all into `_site/themes/` to compare locally. Fonts it references as `url("fonts/name.woff2")` must be in `app/assets/fonts/` and are copied at build time.

Pushes to `main` are tested and deployed to GitHub Pages.
