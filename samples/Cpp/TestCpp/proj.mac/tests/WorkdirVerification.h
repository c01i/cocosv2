// Explicit Debug integration check. The caller supplies the external fixture directory.
static BOOL verifyWorkingDirectory()
{
    using namespace cocos2d;
    CCFileUtilsMac *files = static_cast<CCFileUtilsMac *>(CCFileUtils::sharedFileUtils());
    NSString *root = [[NSFileManager defaultManager] currentDirectoryPath];
    const char *names[] = {"workdir-root.txt", "Images/grossini.png"};
    BOOL passed = YES;
    for (int i = 0; i < 2; ++i) {
        NSString *expected = [root stringByAppendingPathComponent:[NSString stringWithUTF8String:names[i]]];
        std::string actual = files->fullPathForFilename(names[i]);
        passed = passed && actual == [expected UTF8String] && files->isFileExist(names[i]);
        unsigned long size = 0;
        unsigned char *bytes = files->getFileData(names[i], "rb", &size);
        NSData *expectedData = [NSData dataWithContentsOfFile:expected];
        NSData *actualData = bytes ? [NSData dataWithBytes:bytes length:size] : nil;
        passed = passed && expectedData && [actualData isEqualToData:expectedData];
        delete [] bytes;
    }
    std::vector<std::string> paths;
    paths.push_back("external");
    files->setSearchPaths(paths);
    std::string nested = files->fullPathForFilename("workdir-nested.txt");
    passed = passed && nested == [[root stringByAppendingPathComponent:@"external/workdir-nested.txt"] UTF8String];
    // A failed switch must preserve both cwd and the configured resource lookup.
    passed = passed && !files->setWorkingDirectory("") &&
        !files->setWorkingDirectory("workdir-root.txt") &&
        [root isEqualToString:[[NSFileManager defaultManager] currentDirectoryPath]] &&
        files->fullPathForFilename("workdir-nested.txt") == nested;
    fprintf(stdout, "%s: workdir root, file bytes, relative search path and failed-switch preservation\n",
        passed ? "PASS" : "FAIL");
    return passed;
}
