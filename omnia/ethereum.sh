#!/usr/bin/env bash

pullOraclePrice () {
    seth --from-wei "$(seth --to-dec "$(seth call "$OMNIA_ORACLE_ADDR" "read()(bytes32)")")"
}

pullOracleTime () {
	seth --to-dec "$(seth call "$OMNIA_ORACLE_ADDR" "age()(uint48)")"
}