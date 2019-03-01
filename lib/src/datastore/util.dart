int combineHash(int hash1, int hash2) =>
    ((hash1 * 31 & 0x1fffffff) + hash2) & 0x1fffffff;
