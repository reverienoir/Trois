# 03. データモデル設計メモ

実装言語は Swift を想定。以下は型の意図を示すスケッチ（細部は Claude Code で確定）。

## 主要モデル

### UserQuery（ユーザーの入力条件）
- `location: Coordinate`（現在地の緯度経度）
- `walkMinutes: Int`（徒歩何分以内か。例: 5 / 10 / 15）
- `budget: BudgetRange?`（予算上限。未指定可）
- `genres: [Genre]`（ジャンル / 気分。複数可、未指定可）
- （v2）`mealTime: MealTime?` … `.morning / .noon / .night`

### Coordinate
- `latitude: Double`
- `longitude: Double`

### Restaurant（飲食店API から取得した候補）
- `id: String`
- `name: String`
- `location: Coordinate`
- `genreName: String`
- `budgetLabel: String`（APIの予算表記。数値比較用に別途正規化も検討）
- `distanceMeters: Int`（現在地からの距離。徒歩分換算に使用）
- `imageURL: URL?`
- `detailURL: URL?`（店舗詳細ページ）
- `address: String?`

### Recommendation（AIが選んだ1軒＝最終的に画面に出すもの）
- `restaurant: Restaurant`
- `reason: String`（AI生成の推薦理由。例:「予算内で評価が安定。駅から近い」）
- `role: RecommendationRole?`（任意: `.honmei`本命 / `.anaba`穴場 / `.buNan`無難 など）

### RecommendationResult（画面に渡す最終結果）
- `picks: [Recommendation]`（**原則ちょうど3件**）
- `query: UserQuery`（再提案・条件変更で再利用）

## 列挙・補助型（例）

- `BudgetRange`: `.under1000 / .under2000 / .under3000 / .noLimit`
- `Genre`: `.chinese / .light / .hearty / .japanese / .cafe …`（APIのジャンルコードへマッピング）
- `MealTime`（v2）: `.morning / .noon / .night`

---

## 徒歩分数 → 距離の換算

不動産表示の慣習に合わせ **徒歩1分 = 80m** を基準にする。

| 徒歩 | おおよその半径 |
|---|---|
| 5分 | 約 400m |
| 10分 | 約 800m |
| 15分 | 約 1200m |

実装上の注意:
- ホットペッパーAPI の `range` は段階指定（1:300m / 2:500m / 3:1000m / 4:2000m / 5:3000m）。
  徒歩分から最も近い `range` を選び、取得後に `distanceMeters` で **徒歩分以内に再フィルタ** すると精度が出る。
- `distanceMeters` は直線距離。実際の徒歩は遠くなるため、表示は「徒歩 約◯分」と曖昧表記にするのが無難。

---

## 予算の扱い（注意点）

- ホットペッパーAPI の予算は **ディナー予算** が基本。ランチ予算は持たない点に注意。
  → v2 で時間帯（朝・昼・夜）を入れる際、昼の予算精度には別途工夫が必要。
- 予算は API の予算コード（`budget`）でフィルタしつつ、表示は人間可読ラベルに変換する。
