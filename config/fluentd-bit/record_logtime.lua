function append_tag(tag, timestamp, record)
    yymmdd, hhddss, nanosecond, zone1, zone2 = string.match(record["timestamp"], "(%d+-%d+-%d+)T(%d+:%d+:%d+).(%d+)([+|-]%d%d)(%d%d)")
    new_record = record
    new_record["@timestamp"] = yymmdd .. "T" .. hhddss .. "." .. nanosecond .. zone1 .. ":" .. zone2
    new_record["log_time"] = yymmdd .. "T" .. hhddss .. ".".. nanosecond .. zone1 .. ":" .. zone2
    return 1, timestamp, new_record
end
