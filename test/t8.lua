local R=FWR
R:BisDirty(); print("pending now", R:BisResult(R.key,1).pending)
NOW=NOW+30; R:BisDirty(); print("pending after 30s", R:BisResult(R.key,1).pending)
