#!/bin/bash
set -e

MAX_LOOPS=5
LOOP_COUNT=1
STATUS="FAIL"

echo "=== Starting AI Pipeline PoC ==="
echo "Issue Title: $ISSUE_TITLE"

# 1. Developer Agent: 初回コード実装
echo "--- Step 1: Developer Agent ---"
DEV_PROMPT="あなたは開発者です。次の要件を満たすJavaScriptコード(src/index.js)とテストコード(test/index.test.js)を作成し、直接ファイルに書き出してください。
要件: $ISSUE_TITLE
詳細: $ISSUE_BODY"

gemini -p "$DEV_PROMPT" --non-interactive -m gemini-2.5-flash

# ループ処理開始
while [ $LOOP_COUNT -le $MAX_LOOPS ]; do
  echo "=== Loop Iteration: $LOOP_COUNT / $MAX_LOOPS ==="

  # 2. Automated Test
  echo "--- Step 2: Running Tests ---"
  TEST_OUTPUT=""
  TEST_PASSED=true
  npm test > test_result.log 2>&1 || TEST_PASSED=false
  TEST_OUTPUT=$(cat test_result.log)

  # 3. Reviewer Agent: 要件検証 & コードレビュー
  echo "--- Step 3: Reviewer Agent ---"
  REVIEW_PROMPT="あなたはコードレビューナーです。以下のソースコード、テスト結果、および元の要件を比較検証してください。
元の要件: $ISSUE_BODY
テスト結果:
$TEST_OUTPUT

ソースコード(src/index.js):
$(cat src/index.js 2>/dev/null || echo 'Not found')

出力は必ず以下のJSONフォーマットのみを返してください。それ以外のテキストは一切含めないでください。
{
  \"status\": \"PASS\" | \"FAIL\",
  \"reason\": \"判定理由の要約\",
  \"issues\": [\"問題点1\", \"問題点2\"]
}"

  REVIEW_RESULT=$(gemini -p "$REVIEW_PROMPT" --non-interactive -m gemini-2.5-pro --output-format json)
  echo "Review Result JSON:"
  echo "$REVIEW_RESULT"

  # JSONからstatusを取得 (jqを使用)
  STATUS_VAL=$(echo "$REVIEW_RESULT" | jq -r '.status // "FAIL"')

  if [ "$TEST_PASSED" = true ] && [ "$STATUS_VAL" = "PASS" ]; then
    echo "=== SUCCESS: All tests passed and Reviewer APPROVED ==="
    STATUS="PASS"
    break
  fi

  echo "=== Review/Test Status: FAIL. Proceeding to Fixer Agent ==="
  if [ $LOOP_COUNT -eq $MAX_LOOPS ]; then
    echo "Reached maximum loop limit ($MAX_LOOPS)."
    break
  fi

  # 4. Fixer Agent: コード自動修正
  echo "--- Step 4: Fixer Agent ---"
  FIX_PROMPT="あなたは問題修復を行うエンジニアです。テスト結果とレビュー指摘事項を元に src/index.js および test/index.test.js を直接修復・書き換えてください。
レビュー結果: $REVIEW_RESULT
テストログ: $TEST_OUTPUT"

  gemini -p "$FIX_PROMPT" --non-interactive -m gemini-2.5-flash

  LOOP_COUNT=$((LOOP_COUNT + 1))
done

# 最終結果判定
if [ "$STATUS" = "PASS" ]; then
  echo "PoC Completed Successfully!"
  exit 0
else
  echo "PoC Failed or Reached Max Loops. Human intervention required."
  exit 1
fi
