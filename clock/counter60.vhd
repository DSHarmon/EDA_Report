-- 声明使用的库
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all; -- 必须包含此库才能使用 unsigned 类型

-- 实体定义
entity counter60 is
    port (
        sys_clk      : in  std_logic;  -- 系统时钟，频率50MHz
        sys_rst_n    : in  std_logic;  -- 复位信号，低电平有效
        btn_pause    : in  std_logic;  -- 暂停/继续按钮
        btn_hour_add : in  std_logic;  -- 小时+1按钮
        btn_min_add  : in  std_logic;  -- 分钟+1按钮
        btn_sec_add  : in  std_logic;  -- 秒+1按钮
        
        stcp         : out std_logic;  -- 输出数据存储寄时钟
        shcp         : out std_logic;  -- 移位寄存器的时钟输入
        ds           : out std_logic;  -- 串行数据输入
        oe           : out std_logic   -- 输出使能信号
    );
end entity counter60;
-- 注意：虽然实体名称仍为counter60，但现在实现的是时钟功能（时:分:秒）

-- 结构体定义
architecture Behavioral of counter60 is

    -- 声明要实例化的子模块 data_gen
    -- 注意：虽然保留了原有接口，但现在data_gen模块实现的是时钟计数功能
    component data_gen
        port (
            sys_clk    : in  std_logic;
            sys_rst_n  : in  std_logic;
            pause_flag : in  std_logic;
            hour_in    : in  unsigned(4 downto 0);
            minute_in  : in  unsigned(5 downto 0);
            second_in  : in  unsigned(5 downto 0);
            hour_out   : out unsigned(4 downto 0);
            minute_out : out unsigned(5 downto 0);
            second_out : out unsigned(5 downto 0);
            data       : buffer unsigned(6 downto 0);
            point      : out std_logic_vector(5 downto 0);
            seg_en     : out std_logic;
            sign       : out std_logic
        );
    end component;
    
    -- 声明要实例化的子模块 clock_control
    component clock_control
        port (
            sys_clk      : in  std_logic;
            sys_rst_n    : in  std_logic;
            btn_pause    : in  std_logic;
            btn_hour_add : in  std_logic;
            btn_min_add  : in  std_logic;
            btn_sec_add  : in  std_logic;
            pause_flag   : out std_logic;
            hour_in      : in  unsigned(4 downto 0);
            minute_in    : in  unsigned(5 downto 0);
            second_in    : in  unsigned(5 downto 0);
            hour_out     : out unsigned(4 downto 0);
            minute_out   : out unsigned(5 downto 0);
            second_out   : out unsigned(5 downto 0)
        );
    end component;

    -- 声明要实例化的子模块 seg_595_dynamic
    -- 注意：seg_dynamic模块内部已修改为时钟显示逻辑，使用6个数码管显示时:分:秒
    component seg_595_dynamic
        port (
            sys_clk   : in  std_logic;
            sys_rst_n : in  std_logic;
            data      : in  unsigned(6 downto 0); -- 保留原有接口以保持兼容性
            point     : in  std_logic_vector(5 downto 0);
            seg_en    : in  std_logic;
            sign      : in  std_logic;
            hour_in   : in  unsigned(4 downto 0);
            minute_in : in  unsigned(5 downto 0);
            second_in : in  unsigned(5 downto 0);
            stcp      : out std_logic;
            shcp      : out std_logic;
            ds        : out std_logic;
            oe        : out std_logic
        );
    end component;

    -- 内部信号，用于连接子模块
    signal data       : unsigned(6 downto 0);
    signal point      : std_logic_vector(5 downto 0);
    signal seg_en     : std_logic;
    signal sign       : std_logic;
    
    -- 时钟控制相关信号
    signal pause_flag : std_logic;
    signal hour_data  : unsigned(4 downto 0);
    signal minute_data: unsigned(5 downto 0);
    signal second_data: unsigned(5 downto 0);
    signal hour_adj   : unsigned(4 downto 0);
    signal minute_adj : unsigned(5 downto 0);
    signal second_adj : unsigned(5 downto 0);

begin

    -- =============================================================================
    -- 实例化 clock_control 模块
    -- =============================================================================
    U_clock_control: clock_control
        port map (
            sys_clk      => sys_clk,
            sys_rst_n    => sys_rst_n,
            btn_pause    => btn_pause,
            btn_hour_add => btn_hour_add,
            btn_min_add  => btn_min_add,
            btn_sec_add  => btn_sec_add,
            pause_flag   => pause_flag,
            hour_in      => hour_data,
            minute_in    => minute_data,
            second_in    => second_data,
            hour_out     => hour_adj,
            minute_out   => minute_adj,
            second_out   => second_adj
        );
    
    -- =============================================================================
    -- 实例化 data_gen 模块
    -- 注意：data_gen模块现在实现的是时钟计数功能，生成时:分:秒数据
    -- =============================================================================
    U_data_gen: data_gen
        port map (
            sys_clk    => sys_clk,
            sys_rst_n  => sys_rst_n,
            pause_flag => pause_flag,
            hour_in    => hour_adj,
            minute_in  => minute_adj,
            second_in  => second_adj,
            hour_out   => hour_data,
            minute_out => minute_data,
            second_out => second_data,
            data       => data,
            point      => point,
            seg_en     => seg_en,
            sign       => sign
        );

    -- =============================================================================
    -- 实例化 seg_595_dynamic 模块
    -- 注意：seg_595_dynamic模块内部已修改为使用6个数码管显示时:分:秒格式
    -- =============================================================================
    U_seg_595_dynamic: seg_595_dynamic
        port map (
            sys_clk   => sys_clk,
            sys_rst_n => sys_rst_n,
            data      => data,      -- 直接连接，类型匹配
            point     => point,
            seg_en    => seg_en,
            sign      => sign,
            hour_in   => hour_data,
            minute_in => minute_data,
            second_in => second_data,
            stcp      => stcp,
            shcp      => shcp,
            ds        => ds,
            oe        => oe
        );

end architecture Behavioral;