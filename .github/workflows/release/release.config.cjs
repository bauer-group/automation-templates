// Central semantic-release config kept in a subfolder.
// Using CJS so --extends can import it reliably.
module.exports = {
  branches: ["main"],
  plugins: [
    "@semantic-release/commit-analyzer",
    "@semantic-release/release-notes-generator",
    ["@semantic-release/changelog", { changelogFile: "CHANGELOG.MD" }],
    [
      "@semantic-release/git",
      {
        assets: ["CHANGELOG.MD", "README.MD"],
        message:
          "chore(release): ${nextRelease.version} [skip ci]\n\n${nextRelease.notes}"
      }
    ],
    "@semantic-release/github"
  ]
};