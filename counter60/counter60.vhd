-- 声明使用的库
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all; -- 必须包含此库才能使用 unsigned 类型

-- 实体定义
entity counter60 is
    port (
        sys_clk   : in  std_logic;  -- 系统时钟，频率50MHz
        sys_rst_n : in  std_logic;  -- 复位信号，低电平有效
        
        stcp      : out std_logic;  -- 输出数据存储寄时钟
        shcp      : out std_logic;  -- 移位寄存器的时钟输入
        ds        : out std_logic;  -- 串行数据输入
        oe        : out std_logic   -- 输出使能信号
    );
end entity counter60;

-- 结构体定义
architecture Behavioral of counter60 is

    -- 声明要实例化的子模块 data_gen
    -- 注意：data 端口为 buffer unsigned(6 downto 0)
    component data_gen
        port (
            sys_clk   : in  std_logic;
            sys_rst_n : in  std_logic;
            data      : buffer unsigned(6 downto 0); -- 与内部信号类型一致
            point     : out std_logic_vector(5 downto 0);
            seg_en    : out std_logic;
            sign      : out std_logic
        );
    end component;

    -- 声明要实例化的子模块 seg_595_dynamic
    -- 注意：data 端口为 in unsigned(6 downto 0)
    component seg_595_dynamic
        port (
            sys_clk   : in  std_logic;
            sys_rst_n : in  std_logic;
            data      : in  unsigned(6 downto 0); -- 与内部信号类型一致
            point     : in  std_logic_vector(5 downto 0);
            seg_en    : in  std_logic;
            sign      : in  std_logic;
            stcp      : out std_logic;
            shcp      : out std_logic;
            ds        : out std_logic;
            oe        : out std_logic
        );
    end component;

    -- 内部信号，用于连接两个子模块
    -- 修正：将 data 信号类型改为 unsigned(6 downto 0)
    signal data  : unsigned(6 downto 0);
    signal point : std_logic_vector(5 downto 0);
    signal seg_en: std_logic;
    signal sign  : std_logic;

begin

    -- =============================================================================
    -- 实例化 data_gen 模块
    -- data 端口为 buffer 模式，必须连接到类型完全匹配的信号
    -- =============================================================================
    U_data_gen: data_gen
        port map (
            sys_clk   => sys_clk,
            sys_rst_n => sys_rst_n,
            data      => data,      -- 直接连接，类型匹配
            point     => point,
            seg_en    => seg_en,
            sign      => sign
        );

    -- =============================================================================
    -- 实例化 seg_595_dynamic 模块
    -- data 端口为 in 模式，直接连接 unsigned 类型的内部信号
    -- =============================================================================
    U_seg_595_dynamic: seg_595_dynamic
        port map (
            sys_clk   => sys_clk,
            sys_rst_n => sys_rst_n,
            data      => data,      -- 直接连接，类型匹配
            point     => point,
            seg_en    => seg_en,
            sign      => sign,
            stcp      => stcp,
            shcp      => shcp,
            ds        => ds,
            oe        => oe
        );

end architecture Behavioral;