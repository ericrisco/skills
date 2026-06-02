# Evals — kotlin-android

These cases are a judgment aid, not automated CI. Run them through the repo's eval harness, or
read them by hand: feed each `should_trigger` prompt to an agent that has this skill's
description loaded and confirm it engages (especially the non-obvious recomposition/rotation
and the Spanish StateFlow phrasings); feed each `should_not_trigger` prompt and confirm the
agent stays out and routes to the named sibling (`compose-multiplatform`, `swift-ios`,
`spring-boot`, `react-native`, `flutter`). For the `capability` case, have the agent implement
the article-list feature and grade the output against the `must_include` rubric — every bullet
should be present (sealed UiState as StateFlow from a @HiltViewModel, lifecycle-aware
collection, Room-as-source-of-truth + Retrofit refresh, scoped coroutines, modern toolchain
floors, no XML/LiveData/kapt). A miss is a signal to tighten the SKILL.md body or description,
not a hard failure.
