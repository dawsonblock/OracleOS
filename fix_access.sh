#!/bin/bash
# Add public access modifiers to all OracleLib Swift files

cd /Users/dawsonblock/Downloads/THE_ORACLE/oracle-system

find oracle/Sources/OracleLib -name '*.swift' | while read f; do
  # Add public to top-level type declarations (not already public/private/internal)
  sed -i '' 's/^final class /public final class /g' "$f"
  sed -i '' 's/^class /public class /g' "$f"
  sed -i '' 's/^struct /public struct /g' "$f"
  sed -i '' 's/^enum /public enum /g' "$f"
  sed -i '' 's/^protocol /public protocol /g' "$f"
  
  # Fix any double-public that may have been created
  sed -i '' 's/^public public /public /g' "$f"
done

echo "Phase 1 done: top-level types"

# Now let's check what we got
echo ""
echo "Public type declarations:"
grep -rn "^public " oracle/Sources/OracleLib --include='*.swift' | grep -E "(class |struct |enum |protocol )" | wc -l

echo ""
echo "Non-public type declarations still remaining:"
grep -rn "^final class \|^class \|^struct \|^enum \|^protocol " oracle/Sources/OracleLib --include='*.swift' | grep -v "^.*:public " | head -20
