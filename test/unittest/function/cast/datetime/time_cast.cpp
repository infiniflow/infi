//
// Created by jinhai on 22-12-23.
//


#include <gtest/gtest.h>
#include "base_test.h"
#include "common/column_vector/column_vector.h"
#include "common/types/value.h"
#include "main/logger.h"
#include "main/stats/global_resource_usage.h"
#include "main/infinity.h"
#include "function/cast/time_cast.h"


class TimeCastTest : public BaseTest {
    void
    SetUp() override {
        infinity::GlobalResourceUsage::Init();
        infinity::Infinity::instance().Init();
    }

    void
    TearDown() override {
        infinity::Infinity::instance().UnInit();
        EXPECT_EQ(infinity::GlobalResourceUsage::GetObjectCount(), 0);
        EXPECT_EQ(infinity::GlobalResourceUsage::GetRawMemoryCount(), 0);
        infinity::GlobalResourceUsage::UnInit();
    }
};

TEST_F(TimeCastTest, date_cast0) {
    using namespace infinity;

    // Try to cast time type to wrong type.
    {
        TimeT source;
        TinyIntT target;
        EXPECT_THROW(TimeTryCastToVarlen::Run(source, target, nullptr), FunctionException);
    }
    {
        TimeT source;
        VarcharT target;


        DataType data_type(LogicalType::kVarchar);
        SharedPtr<ColumnVector> col_varchar = MakeShared<ColumnVector>(data_type);
        col_varchar->Initialize();

        EXPECT_THROW(TimeTryCastToVarlen::Run(source, target, col_varchar), NotImplementException);
    }
}


TEST_F(TimeCastTest, date_cast1) {
    using namespace infinity;

    // Call BindDateCast with wrong type of parameters
    {
        DataType target_type(LogicalType::kDecimal);
        EXPECT_THROW(BindTimeCast(target_type), TypeException);
    }

    DataType source_type(LogicalType::kTime);
    SharedPtr<ColumnVector> col_source = MakeShared<ColumnVector>(source_type);
    col_source->Initialize();
    for (i64 i = 0; i < DEFAULT_VECTOR_SIZE; ++ i) {
        Value v = Value::MakeTime(TimeT(static_cast<i32>(i)));
        col_source->AppendValue(v);
        Value vx = col_source->GetValue(i);
    }
    for (i64 i = 0; i < DEFAULT_VECTOR_SIZE; ++ i) {
        Value vx = col_source->GetValue(i);
        EXPECT_EQ(vx.type().type(), LogicalType::kTime);
        EXPECT_FLOAT_EQ(vx.value_.time.value, static_cast<i32>(i));
    }
    // cast time column vector to varchar column vector
    {
        DataType target_type(LogicalType::kVarchar);
        auto source2target_ptr = BindTimeCast(target_type);
        EXPECT_NE(source2target_ptr.function, nullptr);

        SharedPtr<ColumnVector> col_target(MakeShared<ColumnVector>(target_type));
        col_target->Initialize();

        CastParameters cast_parameters;
        EXPECT_THROW(source2target_ptr.function(col_source, col_target, DEFAULT_VECTOR_SIZE, cast_parameters), NotImplementException);
    }
}