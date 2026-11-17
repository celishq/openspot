# Prints the change of the last version against the versions before it, split by tabs: the day of the change, how many
# calls failed, and the CPU of a call. Prints nothing for one version.
END {
  if (n < 2) exit
  for (r = 1; r < n; r++) { load(r); runs += v["runs"]; failed += v["failures"]; spent += v["cpu"] }
  load(n)
  printf "%s\t%d of %d → %d of %d\t%s → %s", substr(v["since"], 1, 10), failed, runs, v["failures"], v["runs"], seconds(runs ? spent / runs : 0), seconds(v["runs"] ? v["cpu"] / v["runs"] : 0)
}
