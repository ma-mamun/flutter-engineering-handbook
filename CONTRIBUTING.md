# Contributing

Thanks for considering a contribution. This handbook gets better mainly through
corrections and lived experience, so small, specific pull requests are the most useful
kind.

## Ways to contribute

- **Fix something wrong.** An outdated API, a broken link, a recommendation that no
  longer holds. Open a PR directly — no issue needed.
- **Fill in a draft page.** Pages marked *Draft* are outlines waiting for content. Pick
  one and write it.
- **Add a tradeoff.** If a page presents one option as universally correct, that is a
  bug. Add the case where it fails.
- **Contribute numbers.** Measured results — frame times, build sizes, cold-start
  figures — with the setup described, beat any amount of assertion.
- **Add an interview question.** Use the interview question issue template, or open a PR
  against the question bank.

## Development setup

```bash
git clone https://github.com/ma-mamun/flutter-engineering-handbook.git
cd flutter-engineering-handbook

python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

./scripts/serve.sh      # live preview at http://127.0.0.1:8000
```

Before pushing, run what CI runs:

```bash
./scripts/check.sh
```

That is `mkdocs build --strict` plus `dart format`, `flutter analyze`, and
`flutter test` over `code/`. The Dart steps are skipped automatically if you do not have
a Flutter SDK installed, so a docs-only contributor needs Python and nothing else.

## Writing

The [style guide](https://github.com/ma-mamun/flutter-engineering-handbook/blob/main/docs/style-guide.md) is the tiebreaker on voice, structure, and
formatting. Two rules matter most:

1. **Lead with the recommendation, then justify it.**
2. **Always name the tradeoff.**

Read the style guide before writing a full page. For a typo fix, do not bother.

## Where things go

| What | Where |
| --- | --- |
| Handbook pages | `docs/part-0N-*/`, `docs/appendix/`, `docs/cheatsheets/` |
| Runnable samples | `code/<topic>/` |
| Reused diagrams | `docs/diagrams/*.mmd` |
| Screenshots and figures | `docs/images/` |
| Logos, banners, social cards | `assets/` |
| Helper scripts | `scripts/` |

If you add a page, add it to the `nav` in `mkdocs.yml`. A page missing from the nav is
unreachable, and `mkdocs build --strict` warns about it.

## Pull request process

1. Branch from `develop`: `git switch develop && git switch -c docs/golden-tests`.
   Branch names: `docs/...`, `code/...`, `fix/...`, `chore/...`, or `feature/chapter-NN`
   for milestone work.
2. Keep the PR focused. One topic per PR reviews far faster than five.
3. Write a [Conventional Commits](https://www.conventionalcommits.org/) message:

   ```
   docs(testing): add golden test setup guide

   Covers golden_toolkit configuration, font loading, and the CI
   font-rendering difference that causes false failures on Linux.
   ```

   Types used here: `docs`, `code`, `fix`, `chore`, `ci`.
4. Fill in the PR template — mainly, say what changed and how you verified it.
5. Open the PR against `develop`. A maintainer reviews. Expect questions about
   tradeoffs; they are not objections.

## Reporting problems

Use the issue templates:

- **Bug report** — something in the site or the sample code is broken.
- **Documentation** — a page is wrong, outdated, or missing.
- **Feature request** — a topic or capability the handbook should have.
- **Interview question** — a question worth adding to the bank.

For anything sensitive, email the address in
[CODE_OF_CONDUCT.md](https://github.com/ma-mamun/flutter-engineering-handbook/blob/main/CODE_OF_CONDUCT.md)
instead of opening a public issue.

## Licensing of contributions

By contributing you agree that your contributions — documentation and code alike — are
licensed under the
[MIT License](https://github.com/ma-mamun/flutter-engineering-handbook/blob/main/LICENSE),
the same terms covering the rest of the project.
