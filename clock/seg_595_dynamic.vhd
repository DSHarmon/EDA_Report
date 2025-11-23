-- 声明使用的库
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- 实体定义
entity seg_595_dynamic is
    port (
        sys_clk   : in  std_logic;                     -- 系统时钟，频率50MHz
        sys_rst_n : in  std_logic;                     -- 复位信号，低有效
        data      : in unsigned(6 downto 0); -- 数码管要显示的值
        point     : in  std_logic_vector(5 downto 0);  -- 小数点显示,高电平有效
        seg_en    : in  std_logic;                     -- 数码管使能信号，高电平有效
        sign      : in  std_logic;                     -- 符号位，高电平显示负号
        -- 添加时钟数据输入端口
        hour_in   : in  unsigned(4 downto 0); -- 小时输入 (0-23)
        minute_in : in  unsigned(5 downto 0); -- 分钟输入 (0-59)
        second_in : in  unsigned(5 downto 0); -- 秒输入 (0-59)
        
        stcp      : out std_logic;                     -- 输出数据存储寄时钟
        shcp      : out std_logic;                     -- 移位寄存器的时钟输入
        ds        : out std_logic;                     -- 串行数据输入
        oe        : out std_logic                      -- 输出使能信号
    );
end entity seg_595_dynamic;

-- 结构体定义
architecture Behavioral of seg_595_dynamic is

    -- 声明要实例化的子模块 seg_dynamic
	component seg_dynamic
		 port (
			  sys_clk   : in  std_logic;
			  sys_rst_n : in  std_logic;
			  data      : in  unsigned(6 downto 0); -- 修改为7位 unsigned
			  point     : in  std_logic_vector(5 downto 0);
			  seg_en    : in  std_logic;
			  sign      : in  std_logic;
			  hour_in   : in  unsigned(4 downto 0); -- 小时输入 (0-23)
			  minute_in : in  unsigned(5 downto 0); -- 分钟输入 (0-59)
			  second_in : in  unsigned(5 downto 0); -- 秒输入 (0-59)
			  sel       : out std_logic_vector(5 downto 0);
			  seg       : out std_logic_vector(7 downto 0)
		 );
	end component;

    -- 声明要实例化的子模块 hc595_ctrl
    component hc595_ctrl
        port (
            sys_clk   : in  std_logic;
            sys_rst_n : in  std_logic;
            sel       : in  std_logic_vector(5 downto 0);
            seg       : in  std_logic_vector(7 downto 0);
            stcp      : out std_logic;
            shcp      : out std_logic;
            ds        : out std_logic;
            oe        : out std_logic
        );
    end component;

    -- 内部信号，用于连接两个子模块
    signal sel : std_logic_vector(5 downto 0);
    signal seg : std_logic_vector(7 downto 0);

begin

    -- =============================================================================
    -- 实例化 seg_dynamic 模块
    -- =============================================================================
	U_seg_dynamic: seg_dynamic
		 port map (
			  sys_clk   => sys_clk,
			  sys_rst_n => sys_rst_n,
			  data      => data, -- 现在类型和宽度都匹配了
			  point     => point,
			  seg_en    => seg_en,
			  sign      => sign,
			  hour_in   => hour_in,
			  minute_in => minute_in,
			  second_in => second_in,
			  sel       => sel,
			  seg       => seg
		 );
    -- =============================================================================
    -- 实例化 hc595_ctrl 模块
    -- =============================================================================
    U_hc595_ctrl: hc595_ctrl
        port map (
            sys_clk   => sys_clk,
            sys_rst_n => sys_rst_n,
            sel       => sel,
            seg       => seg,
            stcp      => stcp,
            shcp      => shcp,
            ds        => ds,
            oe        => oe
        );

end architecture Behavioral;