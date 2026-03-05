# [ALP-1403] Multi-language architecture: LanguageDescriptor, per-lang modules, named imports

     ISSUE_ID  Title                                                                   Priority  State  Tags
[ ]  ALP-1404  1.1 Define LanguageDescriptor trait and LanguageTestPatterns struct     High      Todo   rust-engineer
[ ]  ALP-1405  1.2 Decompose private_members.rs into directory module                  High      Todo   rust-engineer
[ ]  ALP-1406  1.3 Decompose call_site_finder.rs into directory module                 High      Todo   rust-engineer
[ ]  ALP-1407  2.1 Implement LanguageDescriptor for all 17 parser structs              High      Todo   rust-engineer
[ ]  ALP-1408  2.2 Add RegisteredLanguage storage and lookup tables to ParserRegistry  High      Todo   rust-engineer
[ ]  ALP-1409  2.3 Update register_language! macro to capture descriptor data          High      Todo   rust-engineer
[ ]  ALP-1410  3.1 Migrate config/mod.rs default_languages to use registry             Medium    Todo   rust-engineer
[ ]  ALP-1411  3.2 Migrate dependency_matcher.rs strip_source_ext to use registry      Medium    Todo   rust-engineer
[ ]  ALP-1412  3.3 Migrate mcp/tools/common.rs is_reexport_file to use registry        Medium    Todo   rust-engineer
[ ]  ALP-1413  3.4 Migrate glossary_builder.rs is_test_file to use registry            Medium    Todo   rust-engineer
[ ]  ALP-1414  4.1 Decompose typescript.rs into directory module                       Medium    Todo   rust-engineer
[ ]  ALP-1415  4.2 Decompose rust.rs into directory module                             Medium    Todo   rust-engineer
[ ]  ALP-1416  4.3 Decompose python.rs into directory module                           Medium    Todo   rust-engineer
[ ]  ALP-1417  4.4 Decompose search.rs into directory module                           Medium    Todo   rust-engineer
[ ]  ALP-1418  5.1 Python named import extraction                                      High      Todo   rust-engineer
[ ]  ALP-1419  5.2 Rust named import extraction                                        High      Todo   rust-engineer
[ ]  ALP-1420  6.1 Implement RsPrivateMemberExtractor                                  Medium    Todo   rust-engineer
[ ]  ALP-1421  6.2 Implement RsCallSiteVerifier bare_call_result                       Medium    Todo   rust-engineer
[ ]  ALP-1422  6.3 Add function_names custom field to Python parser                    Low       Todo   rust-engineer
[ ]  ALP-1423  6.4 Add function_names custom field to Rust parser                      Low       Todo   rust-engineer
[ ]  ALP-1424  7.1 Extract tests from db/writer.rs                                     Low       Todo   rust-engineer
[ ]  ALP-1425  7.2 Extract tests from cli/search.rs                                    Low       Todo   rust-engineer
[ ]  ALP-1426  7.3 Extract tests from format/yaml_formatters.rs                        Low       Todo   rust-engineer
[ ]  ALP-1427  7.4 Extract file/resolve utilities from cli/mod.rs                      Low       Todo   rust-engineer
