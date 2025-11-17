-- 声明使用的库
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- 实体定义
entity bcd_8421 is
    generic (
        -- 100ms 计数器最大值 (50MHz 时钟)
        -- 计算公式: (时钟频率 * 目标时间) - 1
        -- 50,000,000 * 0.1s = 5,000,000
        CNT_100MS_MAX : integer := 4999999 
    );
    port (
        sys_clk    : in  std_logic;                     -- 系统时钟，频率50MHz
        sys_rst_n  : in  std_logic;                     -- 复位信号，低电平有效
        
        -- 与原 bcd_8421 模块兼容的 BCD 码输出
        unit       : out unsigned(3 downto 0);          -- 个位 BCD 码 (0-9)
        ten        : out unsigned(3 downto 0);          -- 十位 BCD 码 (0-5)
        hun        : out unsigned(3 downto 0);          -- 百位 BCD 码 (始终为 0)
        tho        : out unsigned(3 downto 0);          -- 千位 BCD 码 (始终为 0)
        t_tho      : out unsigned(3 downto 0);          -- 万位 BCD 码 (始终为 0)
        h_hun      : out unsigned(3 downto 0);          -- 十万位 BCD 码 (始终为 0)
        
        -- 新增：直接输出计数值 (0-59)，方便观察和调试
        seg_data   : out unsigned(5 downto 0)          
    );
end entity bcd_8421;

-- 结构体定义
architecture Behavioral of bcd_8421 is

    -- 内部信号声明
    -- 100ms 计数器
    signal cnt_100ms : unsigned(22 downto 0);
    -- 100ms 脉冲标志
    signal cnt_flag  : std_logic;
    -- 60进制计数器的寄存器，范围 0 to 59
    signal count_reg : unsigned(5 downto 0);

begin

    -- =============================================================================
    -- 1. 100ms 定时器 (与之前的 data_gen 模块逻辑相同)
    -- =============================================================================
    process(sys_clk, sys_rst_n)
    begin
        if sys_rst_n = '0' then
            cnt_100ms <= (others => '0');
        elsif rising_edge(sys_clk) then
            if cnt_100ms = to_unsigned(CNT_100MS_MAX, cnt_100ms'length) then
                cnt_100ms <= (others => '0');
            else
                cnt_100ms <= cnt_100ms + 1;
            end if;
        end if;
    end process;

    -- 产生 100ms 脉冲标志
    process(sys_clk, sys_rst_n)
    begin
        if sys_rst_n = '0' then
            cnt_flag <= '0';
        elsif rising_edge(sys_clk) then
            if cnt_100ms = to_unsigned(CNT_100MS_MAX - 1, cnt_100ms'length) then
                cnt_flag <= '1';
            else
                cnt_flag <= '0';
            end if;
        end if;
    end process;

    -- =============================================================================
    -- 2. 60进制计数器 (0 to 59)
    -- =============================================================================
    process(sys_clk, sys_rst_n)
    begin
        if sys_rst_n = '0' then
            count_reg <= (others => '0');
        elsif rising_edge(sys_clk) then
            if cnt_flag = '1' then
                if count_reg = to_unsigned(59, count_reg'length) then
                    count_reg <= (others => '0'); -- 计数到59，清零
                else
                    count_reg <= count_reg + 1;   -- 否则，递增
                end if;
            end if;
        end if;
    end process;

    -- =============================================================================
    -- 3. 组合逻辑：将计数值转换为 BCD 码 (个位和十位)
    -- =============================================================================
    -- 个位 = 计数值 mod 10
    unit <= resize(count_reg mod 10, unit'length);
    -- 十位 = 计数值 / 10 (整数除法)
    ten  <= resize(count_reg / 10, ten'length);

    -- 高位BCD码始终为0
    hun   <= (others => '0');
    tho   <= (others => '0');
    t_tho <= (others => '0');
    h_hun <= (others => '0');
    
    -- 直接输出计数值
    seg_data <= count_reg;

end architecture Behavioral;