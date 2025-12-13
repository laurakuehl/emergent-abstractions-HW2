#!/usr/bin/env bash
set -euo pipefail

# Default training command can be overridden, e.g. TRAIN_CMD="python -u train.py".
TRAIN_CMD=${TRAIN_CMD:-python train.py}
ROOT_OUTDIR=${ROOT_OUTDIR:-runs/hier_dataset_matrix}
# Length pressure used in the length_cost conditions.
LENGTH_COST_VALUE=${LENGTH_COST_VALUE:-0.003}

# Hyperparameters that must stay constant across the matrix.
COMMON_FLAGS=(
  --save True
  --num_of_runs 1
  --batch_size 32
  --n_epochs 100
  --learning_rate 0.001
  --game_size 10
  --hidden_size 128
  --temp_update 0.99
  --temperature 2
  --vocab_size_factor 3
  --zero_shot True
)

run_one() {
  local dataset=$1       # flat | hierarchical
  local split=$2         # generic | specific
  local context=$3       # unshared | shared
  local cost=$4          # no_cost | length_cost
  local seed=$5
  local dims_label=$6
  shift 6
  local dims_flags=("$@")
  local outdir="${ROOT_OUTDIR}/dimensions=${dims_label}/dataset=${dataset}/split=${split}/context=${context}/cost=${cost}/seed=${seed}"

  local -a shared_flag=(--shared_context False)
  if [[ "${context}" == "shared" ]]; then
    shared_flag=(--shared_context True)
  fi

  local -a cost_flag=(--length_cost 0.0)
  if [[ "${cost}" == "length_cost" ]]; then
    cost_flag=(--length_cost "${LENGTH_COST_VALUE}")
  fi

  echo "Launching dataset=${dataset}, split=${split}, context=${context}, cost=${cost}, seed=${seed}"
  # shellcheck disable=SC2086
  ${TRAIN_CMD} \
    "${COMMON_FLAGS[@]}" \
    "${dims_flags[@]}" \
    --dataset_structure "${dataset}" \
    --zero_shot_test "${split}" \
    --random_seed "${seed}" \
    --outdir "${outdir}" \
    "${shared_flag[@]}" \
    "${cost_flag[@]}"
}

DATASETS=(flat hierarchical)
SPLITS=(generic specific)
CONTEXTS=(unshared shared)
COSTS=(no_cost length_cost)
SEEDS=(0 1 2 3 4)
DIMENSION_SETS=(
  "D(3,4)=4 4 4"
  "D(4,4)=4 4 4 4"
  "D(3,8)=8 8 8"
)

for dim_entry in "${DIMENSION_SETS[@]}"; do
  dims_label=${dim_entry%%=*}
  dims_string=${dim_entry#*=}
  read -r -a dims_array <<<"${dims_string}"
  dim_flags=(--dimensions "${dims_array[@]}")

  for dataset in "${DATASETS[@]}"; do
    for split in "${SPLITS[@]}"; do
      for context in "${CONTEXTS[@]}"; do
        for cost in "${COSTS[@]}"; do
          for seed in "${SEEDS[@]}"; do
            run_one "${dataset}" "${split}" "${context}" "${cost}" "${seed}" "${dims_label}" "${dim_flags[@]}"
          done
        done
      done
    done
  done
done
