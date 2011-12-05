#!/bin/sh -e

export HETS_HOLLIGHT_TOOLS=$PWD
export HETS_HOL_DIR=/usr/share/hol-light
export HETS_OCAML_LIB_DIR=/usr/lib/ocaml/compiler-libs

rm -f /tmp/exportml_done
dmtcp_coordinator --background
(while [ ! -e /tmp/exportml_done ]
 do
   sleep 0.1
done
echo "------------------------------ Creating Checkpoint"
dmtcp_command --quiet --bcheckpoint
echo "------------------------------ Killing Process & Quitting Coordinator"
dmtcp_command --quiet --quit
echo "------------------------------ Killed Process"
) &
dmtcp_checkpoint --quiet ocaml -w a -init $HETS_HOLLIGHT_TOOLS/export.ml

echo "----------------------------- Moving Image"
mv -f ckpt_ocamlrun_* hol_light.dmtcp
rm -f dmtcp_restart_script*.sh
