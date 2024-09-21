%
% This file is part of uf2tool.
%
% Copyright 2022 Paul Guyot <pguyot@kallisys.net>
%
% Licensed under the Apache License, Version 2.0 (the "License");
% you may not use this file except in compliance with the License.
% You may obtain a copy of the License at
%
%    http://www.apache.org/licenses/LICENSE-2.0
%
% Unless required by applicable law or agreed to in writing, software
% distributed under the License is distributed on an "AS IS" BASIS,
% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
% See the License for the specific language governing permissions and
% limitations under the License.
%
% SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
%

-module(uf2tool).

-export([main/1, uf2join/2, uf2create/4, binary_to_uf2/3]).
-export_type([family_id/0]).

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-endif.

%%% UF2 defines
-define(UF2_MAGIC_START0, 16#0A324655).
-define(UF2_MAGIC_START1, 16#9E5D5157).
-define(UF2_MAGIC_END, 16#0AB16F30).

-define(UF2_FLAG_FAMILY_ID_PRESENT, 16#00002000).

%%% Pico defines
-define(UF2_PICO_FLAGS, ?UF2_FLAG_FAMILY_ID_PRESENT).
-define(UF2_PICO_PAGE_SIZE, 256).
-define(UF2_PICO_FAMILY_ID_RP2040, 16#E48BFF56).
-define(UF2_PICO_FAMILY_ID_ABSOLUTE, 16#E48BFF57).
-define(UF2_PICO_FAMILY_ID_DATA, 16#E48BFF58).
-define(UF2_PICO_FAMILY_ID_RP2350_ARM_S, 16#E48BFF59).
-define(UF2_PICO_FAMILY_ID_RP2350_RISCV, 16#E48BFF5A).
-define(UF2_PICO_FAMILY_ID_RP2350_ARM_NS, 16#E48BFF5B).

-type family_id() ::
    rp2040 | absolute | data | rp2450_arm_s | rp2350_riscv | rp2350_arm_ns | universal | integer().

main([]) ->
    io:format("UF2 Tool: create or join UF2 binaries, for example for Raspberry Pi Pico\n");
main(["-h"]) ->
    usage();
main(["help"]) ->
    usage();
main(["join", "-o", Output | Sources]) when length(Sources) > 1 ->
    uf2join(Output, Sources);
main(["create", "-o", Output, "-f", FamilyStr, "-s", StartAddrStr, Image]) ->
    StartAddr = parse_addr(StartAddrStr),
    Family = parse_family(FamilyStr),
    uf2create(Output, Family, StartAddr, Image);
main(["create", "-o", Output, "-s", StartAddrStr, Image]) ->
    StartAddr = parse_addr(StartAddrStr),
    uf2create(Output, ?UF2_PICO_FAMILY_ID_RP2040, StartAddr, Image);
main(_) ->
    io:format("Syntax error\n"),
    usage(),
    erlang:halt(2).

usage() ->
    % rebar3 builds version string for us using git tag
    ok = application:load(?MODULE),
    {ok, Version} = application:get_key(?MODULE, vsn),
    io:format("UF2 Tool ~s\n\n", [Version]),
    io:format("Usage:\n"),
    io:format("  uf2tool help | -h\n"),
    io:format("    Display this message\n\n"),
    io:format("  uf2tool join -o combined.uf2 first.uf2 second.uf2...\n"),
    io:format("    Join two or more UF2 binaries\n\n"),
    io:format("  uf2tool create -o new.uf2 [-f family] -s start_addr image.avm\n"),
    io:format("    Create a UF2 image from a binary file (image.avm), suitable for the Pico\n"),
    io:format(
        "    Family can be rp2040 | absolute | data | rp2350_arm_s | rp2350_riscv | rp2350_arm_ns | universal\n"
    ),
    io:format("    data is suitable for rp2350 (pico2)\n"),
    io:format("    universal joins a rp2040 and a data uf2, suitable for both RP2040 and RP2350\n"),
    ok.

parse_addr("0x" ++ AddrHex) ->
    list_to_integer(AddrHex, 16);
parse_addr("16#" ++ AddrHex) ->
    list_to_integer(AddrHex, 16);
parse_addr(AddrDec) ->
    list_to_integer(AddrDec).

parse_family(String) when is_list(String) ->
    try
        parse_family0(list_to_existing_atom(String))
    catch
        error:badarg ->
            io:format("Unknown family\n"),
            io:format(
                "Family can be rp2040 | absolute | data | rp2350_arm_s | rp2350_riscv | rp2350_arm_ns\n"
            ),
            unknown
    end.

-spec parse_family0(family_id()) -> integer() | universal.
parse_family0(rp2040) -> ?UF2_PICO_FAMILY_ID_RP2040;
parse_family0(absolute) -> ?UF2_PICO_FAMILY_ID_ABSOLUTE;
parse_family0(data) -> ?UF2_PICO_FAMILY_ID_DATA;
parse_family0(rp2350_arm_s) -> ?UF2_PICO_FAMILY_ID_RP2350_ARM_S;
parse_family0(rp2350_riscv) -> ?UF2_PICO_FAMILY_ID_RP2350_RISCV;
parse_family0(rp2350_arm_ns) -> ?UF2_PICO_FAMILY_ID_RP2350_ARM_NS;
parse_family0(universal) -> universal;
parse_family0(Integer) when is_integer(Integer) -> Integer;
parse_family0(_Unknown) -> throw(badarg).

%%%

%% @doc Join several UF2s into a single UF2.
%% This function shall not be used for universal UF2 (which are just catenated)
%% but to combine several UF2 for the same platform.
%% @param OutputPath path to create the combined UF2 to
%% @param Sources files to combine
%% @returns ok
uf2join(OutputPath, Sources) ->
    SourceBins = [Bin || {ok, Bin} <- [file:read_file(Source) || Source <- Sources]],
    BlocksCount = lists:sum([byte_size(SourceBin) || SourceBin <- SourceBins]) div 512,
    {BlocksCount, OutputBinsLR} = lists:foldl(
        fun(SourceBin, {StartBlock, Acc}) ->
            {NewBlockStart, RewrittenBin} = rewrite_block_indices(
                StartBlock, BlocksCount, SourceBin
            ),
            {NewBlockStart, [RewrittenBin | Acc]}
        end,
        {0, []},
        SourceBins
    ),
    ok = file:write_file(OutputPath, lists:reverse(OutputBinsLR)).

rewrite_block_indices(BlockIndex, BlocksCount, Bin) ->
    rewrite_block_indices0(BlockIndex, BlocksCount, Bin, []).

rewrite_block_indices0(LastBlock, _BlocksCount, <<>>, Acc) ->
    {LastBlock, lists:reverse(Acc)};
rewrite_block_indices0(BlockIndex, BlocksCount, <<Page:512/binary, Tail/binary>>, Acc) ->
    <<
        ?UF2_MAGIC_START0:32/little,
        ?UF2_MAGIC_START1:32/little,
        Flags:32/little,
        TargetAddr:32/little,
        PageSize:32/little,
        _BlockNo:32/little,
        _NumBlocks:32/little,
        FamilyIdOrFileSize:32/little,
        Data:476/binary,
        ?UF2_MAGIC_END:32/little
    >> = Page,
    Rewritten = <<
        ?UF2_MAGIC_START0:32/little,
        ?UF2_MAGIC_START1:32/little,
        Flags:32/little,
        TargetAddr:32/little,
        PageSize:32/little,
        BlockIndex:32/little,
        BlocksCount:32/little,
        FamilyIdOrFileSize:32/little,
        Data:476/binary,
        ?UF2_MAGIC_END:32/little
    >>,
    rewrite_block_indices0(BlockIndex + 1, BlocksCount, Tail, [Rewritten | Acc]).

%% @doc Create a UF2 file from a data file
%% @param OutputPath path to create the file to
%% @param FamilyID id of the family for the UF2
%% @param StartAddr start address of the data
%% @param ImagePath path to the data file to convert to UF2
%% @returns ok
-spec uf2create(string(), family_id(), integer(), string()) -> ok.
uf2create(OutputPath, FamilyID, StartAddr, ImagePath) ->
    {ok, ImageBin} = file:read_file(ImagePath),
    OutputBin = binary_to_uf2(FamilyID, StartAddr, ImageBin),
    ok = file:write_file(OutputPath, OutputBin).

%% @doc Create a UF2 binary from a binary
%% @param FamilyID id of the family for the UF2
%% @param StartAddr start address of the data
%% @param ImageBin binary to embed into UF2
%% @returns the UF2 binary
-spec binary_to_uf2(family_id(), integer(), binary()) -> binary().
binary_to_uf2(FamilyID, StartAddr, ImageBin) ->
    Family = parse_family0(FamilyID),
    BlocksCount0 = byte_size(ImageBin) div ?UF2_PICO_PAGE_SIZE,
    BlocksCount =
        BlocksCount0 +
            if
                byte_size(ImageBin) rem ?UF2_PICO_PAGE_SIZE =:= 0 -> 0;
                true -> 1
            end,
    OutputBin =
        case Family of
            universal ->
                % Universal is a catenation (not a join) of two uf2s
                OutputBinRP2040 = binary_to_uf2_1(
                    ?UF2_PICO_FAMILY_ID_RP2040, 0, BlocksCount, StartAddr, ImageBin, []
                ),
                OutputBinRP2350 = binary_to_uf2_1(
                    ?UF2_PICO_FAMILY_ID_DATA, 0, BlocksCount, StartAddr, ImageBin, []
                ),
                list_to_binary([OutputBinRP2040, OutputBinRP2350]);
            _ ->
                binary_to_uf2_1(Family, 0, BlocksCount, StartAddr, ImageBin, [])
        end,
    OutputBin.

binary_to_uf2_1(_Family, _BlockIndex, _BlocksCount, _BaseAddr, <<>>, Acc) ->
    lists:reverse(Acc);
binary_to_uf2_1(Family, BlockIndex, BlocksCount, BaseAddr, ImageBin, Acc) ->
    {PageBin, Tail} =
        if
            byte_size(ImageBin) >= ?UF2_PICO_PAGE_SIZE ->
                split_binary(ImageBin, ?UF2_PICO_PAGE_SIZE);
            true ->
                {ImageBin, <<>>}
        end,
    PaddedData = pad_binary(PageBin, 476),
    Block = [
        <<
            ?UF2_MAGIC_START0:32/little,
            ?UF2_MAGIC_START1:32/little,
            ?UF2_PICO_FLAGS:32/little,
            BaseAddr:32/little,
            ?UF2_PICO_PAGE_SIZE:32/little,
            BlockIndex:32/little,
            BlocksCount:32/little,
            Family:32/little
        >>,
        PaddedData,
        <<?UF2_MAGIC_END:32/little>>
    ],
    binary_to_uf2_1(Family, BlockIndex + 1, BlocksCount, BaseAddr + ?UF2_PICO_PAGE_SIZE, Tail, [
        Block | Acc
    ]).

pad_binary(Bin, Len) ->
    PadCount = Len - byte_size(Bin),
    Pad = binary:copy(<<0>>, PadCount),
    [Bin, Pad].

-ifdef(TEST).

% echo -n "Hello" > onepage.bin
% picotool uf2 convert one_page.bin -t bin one_page.uf2 -o 0x10180000
% md5 one_page.uf2
binary_to_uf2_one_page_test() ->
    Binary = <<"Hello">>,
    Output = binary_to_uf2(?UF2_PICO_FAMILY_ID_RP2040, 16#10180000, Binary),
    OutputMD5 = crypto:hash(md5, Output),
    ?assertEqual(<<16#fb5b22f05965148196fe2e49f65b2dfe:128>>, OutputMD5).

% echo -n "Hello" > onepage.bin
% picotool uf2 convert one_page.bin -t bin one_page.uf2 -o 0x10180000 --family data
% md5 one_page.uf2
binary_to_uf2_one_page_data_test() ->
    Binary = <<"Hello">>,
    Output = binary_to_uf2(?UF2_PICO_FAMILY_ID_DATA, 16#10180000, Binary),
    OutputMD5 = crypto:hash(md5, Output),
    ?assertEqual(<<16#fb727c2ec347dc6a3725484042d4e300:128>>, OutputMD5).

% head -c "256" /dev/zero | tr '\00' '1' > 256bytes.bin
% picotool uf2 convert 256bytes.bin -t bin 256bytes.uf2 -o 0x10180000
% md5 256bytes.uf2
binary_to_uf2_256bytes_test() ->
    Binary = list_to_binary(lists:duplicate(256, $1)),
    Output = binary_to_uf2(?UF2_PICO_FAMILY_ID_RP2040, 16#10180000, Binary),
    OutputMD5 = crypto:hash(md5, Output),
    ?assertEqual(<<16#59e9df59898c5f5f947ec28e56ecd1f8:128>>, OutputMD5).

% head -c 2048 /dev/zero | tr '\00' '2' > 2048bytes.bin
% picotool uf2 convert 2048bytes.bin -t bin 2048bytes-2040.uf2 -o 0x10180000 --family rp2040
% picotool uf2 convert 2048bytes.bin -t bin 2048bytes-2350.uf2 -o 0x10180000 --family data
% cat 2048bytes-2040.uf2 2048bytes-2350.uf2 > 2048bytes.uf2
% md5 2048bytes.uf2
binary_to_uf2_universal_test() ->
    Binary = list_to_binary(lists:duplicate(2048, $2)),
    Output = binary_to_uf2(universal, 16#10180000, Binary),
    OutputMD5 = crypto:hash(md5, Output),
    ?assertEqual(<<16#ee89c911b39e3f2397d5ea7a4aa98d43:128>>, OutputMD5).

-endif.
