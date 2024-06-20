#include "stf-inc/stf_writer.hpp"
#include "stf-inc/stf_reader.hpp"
#include "stf-inc/stf_record_types.hpp"

#include "gtest/gtest.h"

int main(int argc, char **argv) {
    ::testing::InitGoogleTest(&argc, argv);
    return RUN_ALL_TESTS();
}

TEST(STFWriterTest, STFWriterBasicTest) {
    uint64_t pc = 0x1000;

    stf::STFWriter stf_writer;

    stf_writer.open("stf_write_test.zstf");
    stf_writer.addTraceInfo(stf::TraceInfoRecord(stf::STF_GEN::STF_GEN_DROMAJO, 
                                                 1, 2, 0, "Trace from Dromajo"));
    stf_writer.setISA(stf::ISA::RISCV);
    stf_writer.setHeaderIEM(stf::INST_IEM::STF_INST_IEM_RV64);
    stf_writer.setTraceFeature(stf::TRACE_FEATURES::STF_CONTAIN_RV64);
    stf_writer.setTraceFeature(stf::TRACE_FEATURES::STF_CONTAIN_PHYSICAL_ADDRESS);
    stf_writer.setHeaderPC(pc);
    stf_writer.finalizeHeader();

    stf_writer << stf::InstOpcode32Record(0x00b60733);
    
    stf_writer.close();

    stf::STFReader stf_reader;
    stf_reader.open("stf_write_test.zstf");

    bool found_trace_info = false;
    bool found_opcode = false;

    for(const auto& record : stf_reader) {
        if (auto trace_info = dynamic_cast<const stf::TraceInfoRecord*>(&record)) {
            EXPECT_EQ(trace_info->getTraceVersion(), 1);
            EXPECT_EQ(trace_info->getISA(), 2);
            EXPECT_EQ(trace_info->getReserved(), 0);
            EXPECT_STREQ(trace_info->getDescription().c_str(), "Trace from Dromajo");
            found_trace_info = true;
        } else if (auto opcode_record = dynamic_cast<const stf::InstOpcode32Record*>(&record)) {
            EXPECT_EQ(opcode_record->getOpcode(), 0x00b60733);
            found_opcode = true;
        }
    }

    stf_reader.close();

    EXPECT_TRUE(found_trace_info);
    EXPECT_TRUE(found_opcode);
}