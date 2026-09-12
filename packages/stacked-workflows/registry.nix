{facetOwner, ...}: {
  documentation.skillDescriptions = {
    stack-fix = "Absorb fixes into correct stack commits";
    stack-plan = "Plan and build a commit stack from description or existing commits";
    stack-split = "Split a large commit into reviewable atomic commits";
    stack-submit = "Sync, validate, push stack, and create stacked PRs";
    stack-summary = "Analyze stack quality, flag violations, produce planner-ready summary";
    stack-test = "Run tests or formatters across commits in a stack";
  };
  fragments.categories.stacked-workflows = {
    scopes = ["packages/${facetOwner}/**"];
    sources = [
      {
        location = "package";
        name = "development";
        dir = facetOwner;
      }
    ];
  };
  update.excludePatterns = ["^stacked-workflows-content$"];
}
