-- 交通灯系统顶层模块
-- 包含主干道和支干道的LED指示灯以及倒计时数码管显示
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity traffic_light_top is
    port (
        sys_clk          : in  std_logic;                     -- 系统时钟，50MHz
        sys_rst_n        : in  std_logic;                     -- 复位信号，低电平有效
        btn_state_change : in  std_logic;                     -- 模式/状态切换按钮（下降沿触发）
        
        -- 主干道LED指示灯（高电平点亮）
        main_road_red    : out std_logic;                     -- 主干道红灯
        main_road_yellow : out std_logic;                     -- 主干道黄灯
        main_road_green  : out std_logic;                     -- 主干道绿灯
        
        -- 支干道LED指示灯（高电平点亮）
        branch_road_red    : out std_logic;                   -- 支干道红灯
        branch_road_yellow : out std_logic;                   -- 支干道黄灯
        branch_road_green  : out std_logic;                   -- 支干道绿灯
        
        -- 数码管控制信号（用于4个数码管）
        seg_stcp         : out std_logic;                     -- 输出数据存储时钟
        seg_shcp         : out std_logic;                     -- 移位寄存器时钟输入
        seg_ds           : out std_logic;                     -- 串行数据输入
        seg_oe           : out std_logic                      -- 输出使能信号（低电平有效）
    );
end entity traffic_light_top;

architecture Behavioral of traffic_light_top is
    -- 声明子模块
    component traffic_light_ctrl is
        port (
            sys_clk          : in  std_logic;
            sys_rst_n        : in  std_logic;
            state_change     : in  std_logic;
            
            -- 交通灯输出
            main_red         : out std_logic;
            main_yellow      : out std_logic;
            main_green       : out std_logic;
            branch_red       : out std_logic;
            branch_yellow    : out std_logic;
            branch_green     : out std_logic;
            
            -- 倒计时输出
            main_countdown   : out unsigned(5 downto 0);       -- 主干道倒计时（秒）
            branch_countdown : out unsigned(5 downto 0)        -- 支干道倒计时（秒）
        );
    end component;
    
    component seg_display_ctrl is
        port (
            sys_clk          : in  std_logic;
            sys_rst_n        : in  std_logic;
            main_countdown   : in  unsigned(5 downto 0);       -- 主干道倒计时（秒）
            branch_countdown : in  unsigned(5 downto 0);       -- 支干道倒计时（秒）
            
            -- 数码管控制信号
            seg_stcp         : out std_logic;
            seg_shcp         : out std_logic;
            seg_ds           : out std_logic;
            seg_oe           : out std_logic
        );
    end component;
    
    component btn_debounce is
        port (
            sys_clk          : in  std_logic;
            sys_rst_n        : in  std_logic;
            btn_in           : in  std_logic;
            btn_out          : out std_logic;                   -- 消抖后的按钮信号
            btn_edge         : out std_logic                    -- 下降沿触发信号
        );
    end component;
    
    -- 内部信号
    signal btn_edge       : std_logic;                       -- 按钮下降沿触发信号
    signal main_countdown : unsigned(5 downto 0);            -- 主干道倒计时
    signal branch_countdown : unsigned(5 downto 0);          -- 支干道倒计时
    
begin
    -- 实例化按钮消抖模块
    U_btn_debounce : btn_debounce
        port map (
            sys_clk  => sys_clk,
            sys_rst_n => sys_rst_n,
            btn_in   => btn_state_change,
            btn_out  => open,  -- 不需要消抖后的电平信号，只需要边沿
            btn_edge => btn_edge
        );
    
    -- 实例化交通灯控制模块
    U_traffic_light_ctrl : traffic_light_ctrl
        port map (
            sys_clk          => sys_clk,
            sys_rst_n        => sys_rst_n,
            state_change     => btn_edge,
            main_red         => main_road_red,
            main_yellow      => main_road_yellow,
            main_green       => main_road_green,
            branch_red       => branch_road_red,
            branch_yellow    => branch_road_yellow,
            branch_green     => branch_road_green,
            main_countdown   => main_countdown,
            branch_countdown => branch_countdown
        );
    
    -- 实例化数码管显示控制模块
    U_seg_display_ctrl : seg_display_ctrl
        port map (
            sys_clk          => sys_clk,
            sys_rst_n        => sys_rst_n,
            main_countdown   => main_countdown,
            branch_countdown => branch_countdown,
            seg_stcp         => seg_stcp,
            seg_shcp         => seg_shcp,
            seg_ds           => seg_ds,
            seg_oe           => seg_oe
        );
    
end architecture Behavioral;