#!/bin/bash
# Phase 2: Add public to inits and methods in OracleLib

cd /Users/dawsonblock/Downloads/THE_ORACLE/oracle-system

find oracle/Sources/OracleLib -name '*.swift' | while read f; do
  # Add public to init declarations (indented, within public types)
  # Match "    init(" that isn't already public/private/internal/convenience/required/override
  sed -i '' '/^    init(/{ /public /! { /private /! { /internal /! { /convenience /! { /required /! { /override /! s/^    init(/    public init(/ } } } } } }' "$f"
  
  # Add public to func declarations (indented, within public types)
  # Match "    func " that isn't already public/private/internal/override/@
  sed -i '' '/^    func /{ /public /! { /private /! { /internal /! { /override /! s/^    func /    public func / } } } }' "$f"
  
  # Add public to static func
  sed -i '' '/^    static func /{ /public /! { /private /! { /internal /! s/^    static func /    public static func / } } }' "$f"
  
  # Add public to static let/var
  sed -i '' '/^    static let /{ /public /! { /private /! { /internal /! s/^    static let /    public static let / } } }' "$f"
  sed -i '' '/^    static var /{ /public /! { /private /! { /internal /! s/^    static var /    public static var / } } }' "$f"
  
  # Add public to var/let properties (4-space indent)
  sed -i '' '/^    var /{ /public /! { /private /! { /internal /! { /weak /! s/^    var /    public var / } } } }' "$f"
  sed -i '' '/^    let /{ /public /! { /private /! { /internal /! s/^    let /    public let / } } }' "$f"
  
  # Add public to lazy var
  sed -i '' '/^    lazy var /{ /public /! { /private /! { /internal /! s/^    lazy var /    public lazy var / } } }' "$f"
  
  # Add public to case in enums (enum cases don't need public)
  # Actually skip cases - enum cases inherit access from the enum
  
  # Fix double-public
  sed -i '' 's/public public /public /g' "$f"
done

echo "Phase 2 done: inits, methods, properties"

# Count results
echo ""
echo "Public init count:"
grep -rn "public init(" oracle/Sources/OracleLib --include='*.swift' | wc -l

echo "Public func count:"
grep -rn "public func\|public static func" oracle/Sources/OracleLib --include='*.swift' | wc -l
