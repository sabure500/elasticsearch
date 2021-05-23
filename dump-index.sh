#!/bin/bash

# ElasticSearchのエンドポイント
#ES_URL=$1
# DUMPを取得するINDEX名
#INDEX=$2

ES_URL='http://localhost:9200'
INDEX=my_index

echo "scroll ID を取得するための初期実行"
RESPONSE=$(curl -H "Content-Type: application/json" -s "${ES_URL}/${INDEX}/_search?scroll=1m" -d @query.json)
SCROLL_ID=$(echo ${RESPONSE} | jq -r ._scroll_id)
HITS_COUNT=$(echo ${RESPONSE} | jq -r '.hits.hits | length')
HITS_SO_FAR=$HITS_COUNT
echo $RESPONSE | jq -c '.hits.hits[]._source' >> $INDEX.json

# echo "Got initial response with ${hits_count} hits and scroll ID ${scroll_id}."

echo "発行したscroll ID を利用して繰り返しINDEXの中身を取得"
i=1
while [ "${HITS_COUNT}" != "0" ]; do
  RESPONSE=$(curl -H "Content-Type: application/json" -s ${ES_URL}/_search/scroll -d "{ \"scroll\": \"1m\", \"scroll_id\": \"$SCROLL_ID\" }")
  SCROLL_ID=$(echo ${RESPONSE} | jq -r ._scroll_id)
  HITS_COUNT=$(echo ${RESPONSE} | jq -r '.hits.hits | length')
  HITS_SO_FAR=$((HITS_SO_FAR + HITS_COUNT))
  # echo "Got response with ${hits_count} hits (hits so far: ${hits_so_far}), new scroll ID ${scroll_id}."
  echo $RESPONSE | jq -c '.hits.hits[]._source' >> $INDEX.json

  i=$(expr $i + 1)
done
echo "Done!"

echo "使い終わったScroll IDの削除"
curl -XDELETE -H "Content-Type: application/json" "${ES_URL}/_search/scroll" -d "
{
    \"scroll_id\" : \"$SCROLL_ID\"
}"

echo "ループ回数: $i"
echo "ヒット総数: $HITS_SO_FAR"

# ElasticSearchのINDEXに改めて挿入できる形に加工するための処理
# tmpfile=$(mktemp)
# trap "rm -rf $tmpdir" EXIT
# cat $INDEX.json | awk '{print $0} NR%1==0 {printf "test\n"}' > ${tmpfile}
# mv ${tmpfile} $INDEX.json
# sed -e "1i test\n" $INDEX.json > $INDEX.json
# sed -e "$d" $INDEX.json > $INDEX.json
